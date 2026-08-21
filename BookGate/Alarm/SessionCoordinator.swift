import SwiftUI
import Observation
import AlarmKit

/// The night-flow phase machine. Thrise was ringing → challenge → done; BookGate extends it to
/// **ringing → gate → settle → session → complete → takeaway → (clean-week? step-up)**. The reading
/// **session is a new phase that runs AFTER the alarm is dismissed** by the camera gate.
///
/// Owns the session timer (whose remaining fraction drives the lamp glow) and the shield lifecycle.
/// Constructor-injected like the rest of the app.
@MainActor @Observable
final class SessionCoordinator {

    enum Phase: Equatable {
        case idle
        case ringing(alarmID: UUID?)   // alarm firing — "Show My Book"
        case gate                       // camera gate: face + hand + book
        case settle                     // post-scan beat: read now / hear last takeaway
        case session                    // timed reading, shield up, lamp shrinking
        case complete                   // "You read today"
        case takeaway                   // optional recorder
        case stepup                     // clean-week step-up prompt
    }

    private(set) var phase: Phase = .idle

    // Resolved firing alarm
    private(set) var firedAlarmID: UUID?
    var firingSchedule: Schedule? { scheduleForID(firedAlarmID) }

    // Session timing
    private(set) var sessionLengthMinutes = 5
    private(set) var secondsLeft = 0
    private(set) var goalReached = false
    private(set) var inOvertime = false
    private(set) var overtimeSecs = 0
    private var sessionTotal = 1

    /// Wall-clock anchors. The session is defined by *when it ends*, not by how many ticks the app
    /// managed to run: the phone is put down (and often locked) mid-session, which suspends the
    /// ticker Task and used to freeze — or badly under-count — the clock. Every published value is
    /// derived from these two dates, so the session stays honest across a background/foreground.
    private var goalAt: Date?
    private var overtimeFrom: Date?

    /// Remaining fraction 1→0 for the lamp glow (the progress indicator). During overtime the goal
    /// is met, so it reports 0 (glow at minimum) while the extra time counts up separately.
    var remainingFraction: Double {
        guard sessionTotal > 0 else { return 0 }
        return max(0, min(1, Double(secondsLeft) / Double(sessionTotal)))
    }

    // Outputs for the complete screen
    private(set) var capturedPhoto: JournalEntry?
    private(set) var completedMinutes = 0
    private(set) var completedStreak = 0

    // Dependencies (injected)
    private let scheduleForID: (UUID?) -> Schedule?
    private let progress: ProgressStore
    private let journal: JournalStore
    private let books: BookStore
    private let settings: ReadingSettings
    private let scheduler: AlarmScheduler
    private let shield: ShieldControlling
    /// Whether the subscription currently permits the paid features. A closure rather than a
    /// stored flag so it is read at the moment it matters, never cached from launch.
    ///
    /// Deliberately **true while entitlement is still unresolved**: only a *confirmed* lapse
    /// may take something away, which is the rule the wall and the alarm scheduling already
    /// follow. Asking "is it a definite yes?" instead denied the shield to a paying reader
    /// whose StoreKit answer had simply not landed yet.
    private let subscriptionAllows: () -> Bool

    private var ticker: Task<Void, Never>?
    private let watchdogDelay: TimeInterval = 120

    init(scheduleForID: @escaping (UUID?) -> Schedule?,
         progress: ProgressStore, journal: JournalStore, books: BookStore,
         settings: ReadingSettings, scheduler: AlarmScheduler, shield: ShieldControlling,
         subscriptionAllows: @escaping () -> Bool = { true }) {
        self.scheduleForID = scheduleForID
        self.progress = progress
        self.journal = journal
        self.books = books
        self.settings = settings
        self.scheduler = scheduler
        self.shield = shield
        self.subscriptionAllows = subscriptionAllows
    }

    // MARK: Entry points

    /// From the AlarmKit update stream. Only a truly idle app promotes to `ringing`; a tick while
    /// the gate/session is on screen is the watchdog and is ignored (the flow is already running).
    func handleAlarmUpdate(alertingIDs ids: [UUID]) {
        guard phase == .idle, let id = ids.first else { return }
        firedAlarmID = id
        phase = .ringing(alarmID: id)
    }

    /// Consume a cross-launch "Show My Book" tap (`OpenGateIntent`) — jump straight to the gate.
    func consumePendingGate() {
        guard let idString = PendingGate.consume(), phase == .idle || phase == .ringing(alarmID: firedAlarmID) else { return }
        firedAlarmID = UUID(uuidString: idString)
        beginGate()
    }

    /// "Begin Reading Now" on Today (manual start, no alarm firing).
    func beginReadingNow() {
        firedAlarmID = scheduleForID(nil)?.id
        beginGate()
    }

    /// From the ringing screen's "Show My Book".
    func showMyBook() { beginGate() }

    /// Snooze from the ringing screen (a one-off 10-minute re-ring, distinct from the 60s nag).
    func snooze(minutes: Int = 10) {
        guard let schedule = firingSchedule else { phase = .idle; return }
        Task {
            let countdown = Alarm.CountdownDuration(preAlert: TimeInterval(minutes * 60), postAlert: nil)
            await AlarmChain.scheduleRing(owner: schedule.id, countdown: countdown, nextCount: 1,
                                          display: AlarmChain.cachedDisplay(schedule.id))
        }
        phase = .idle
    }

    /// "Skip Today" — dismiss the alarm for tonight without reading.
    func skipTonight() {
        if let schedule = firingSchedule {
            Task { await scheduler.disarmWatchdog(owner: schedule) }   // cancel re-rings, keep nightly
        }
        resetSession()
        phase = .idle
    }

    // MARK: Gate

    private func beginGate() {
        phase = .gate
        // Stop the nag chain now that the user has engaged, but arm a watchdog so an abandoned gate
        // rings again.
        if let schedule = firingSchedule {
            Task { await scheduler.armWatchdog(after: watchdogDelay, owner: schedule) }
        }
    }

    /// The gate detected face + hand + book (or the user used the manual fallback). Dismiss the
    /// alarm fully, capture tonight's journal photo, and settle.
    func gateSucceeded(photo jpeg: Data?) {
        if let schedule = firingSchedule {
            Task { await scheduler.disarmWatchdog(owner: schedule) }   // alarm done
        }
        if let jpeg {
            capturedPhoto = journal.addPhoto(jpeg, bookId: books.currentReading?.idString)
        }
        phase = .settle
    }

    // MARK: Session

    /// From the settle screen: start the timed session (shield up).
    func startSession(now: Date = .now) {
        sessionLengthMinutes = settings.effectiveTonightLength
        sessionTotal = max(1, sessionLengthMinutes * 60)
        goalAt = now.addingTimeInterval(TimeInterval(sessionTotal))
        overtimeFrom = nil
        secondsLeft = sessionTotal
        goalReached = false
        inOvertime = false
        overtimeSecs = 0
        // App shielding is a paid feature. `ShieldControlling` has always documented
        // "a lapsed subscription ⇒ shield OFF" and nothing enforced it — this is where the
        // caller stops raising the window. A *confirmed* lapse only: see `subscriptionAllows`.
        if subscriptionAllows() { shield.beginReadingWindow() }
        phase = .session
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    /// Recompute the published clock from the wall-clock anchors. Safe to call at any time — the
    /// ticker calls it every second, and `AppServices` calls it on every foreground so a session
    /// that ran while the app was suspended shows the right numbers the instant it comes back.
    func syncClock(now: Date = .now) {
        guard phase == .session else { return }
        if let overtimeFrom {
            overtimeSecs = max(0, Int(now.timeIntervalSince(overtimeFrom).rounded()))
        }
        guard let goalAt else { return }
        let left = Int(goalAt.timeIntervalSince(now).rounded(.up))
        secondsLeft = max(0, left)
        if secondsLeft == 0 && !goalReached {
            goalReached = true
            Haptics.goalReached()
        }
    }

    private func tick() { syncClock() }

    /// At goal: keep reading into overtime (the glow stays at minimum; a brighter arc counts up).
    func keepReading(now: Date = .now) {
        guard goalReached else { return }
        inOvertime = true
        overtimeFrom = now
        overtimeSecs = 0
    }

    /// Finish the session affirmatively (at/after goal, or in overtime) — records the night.
    func finishSession() {
        recordAndComplete()
    }

    /// End before the goal — a quiet bail. Lifts the shield, does NOT record the night (no streak).
    func endEarly() {
        ticker?.cancel()
        shield.endReadingWindow()
        resetSession()
        phase = .idle
    }

    private func recordAndComplete() {
        ticker?.cancel()
        let minutes = sessionLengthMinutes
        let elapsed = TimeInterval(sessionTotal - secondsLeft) + Double(overtimeSecs)
        Haptics.success()
        progress.recordNight(minutes: minutes, elapsed: elapsed)
        if let bookId = books.currentReading?.idString {
            books.recordSession(bookId: bookId, minutes: minutes)
        }
        shield.endReadingWindow()
        settings.clearTonightOverride()
        completedMinutes = minutes
        completedStreak = progress.liveStreak
        phase = .complete
    }

    // MARK: Complete → takeaway → step-up

    func recordTakeaway() { phase = .takeaway }

    /// Called when the takeaway is saved or skipped — skipping never breaks the streak.
    func finishedTakeawayStep() { evaluateStepUp() }

    /// From the complete screen's "Not now".
    func skipTakeaway() { evaluateStepUp() }

    private func evaluateStepUp() {
        // Offer the step-up only after a clean week at the current length, once, right after a
        // session — never as a push.
        let cleanWeek = progress.liveStreak >= 7
        if cleanWeek && settings.mayOfferStepUp() {
            phase = .stepup
        } else {
            finish()
        }
    }

    func acceptStepUp() {
        if let next = settings.nextLengthUp { settings.defaultLength = next }
        settings.stepUpHandledWeek = ReadingSettings.currentWeek()
        finish()
    }

    func declineStepUp() {
        settings.stepUpHandledWeek = ReadingSettings.currentWeek()
        finish()
    }

    // MARK: Teardown

    /// Return to Today.
    func finish() {
        resetSession()
        phase = .idle
    }

    private func resetSession() {
        ticker?.cancel(); ticker = nil
        secondsLeft = 0; sessionTotal = 1
        goalAt = nil; overtimeFrom = nil
        goalReached = false; inOvertime = false; overtimeSecs = 0
        capturedPhoto = nil
    }

    #if DEBUG
    /// Jump straight to a phase for headless screenshots.
    func debugJump(to phase: Phase) {
        switch phase {
        case .session:
            sessionLengthMinutes = settings.effectiveTonightLength
            sessionTotal = max(1, sessionLengthMinutes * 60)
            secondsLeft = Int(Double(sessionTotal) * 0.68)
            goalAt = Date().addingTimeInterval(TimeInterval(secondsLeft))
        case .complete, .takeaway, .stepup:
            completedMinutes = settings.effectiveTonightLength
            completedStreak = progress.liveStreak
        default: break
        }
        self.phase = phase
    }
    #endif
}
