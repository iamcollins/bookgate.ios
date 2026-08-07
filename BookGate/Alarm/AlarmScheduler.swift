import AlarmKit
import SwiftUI

/// Metadata attached to every BookGate alarm — the owning `Schedule.id` plus the book title used
/// to render the alert. **Display-only:** AlarmKit does not surface metadata back on the
/// `alarmUpdates` stream, so the app never resolves a fired alarm from this — identity travels
/// through the intents (see `AlarmChain`).
nonisolated struct BookGateAlarmMetadata: AlarmMetadata {
    var owner: UUID
    var bookTitle: String

    init(owner: UUID, display: AlarmChain.RingDisplay) {
        self.owner = owner
        self.bookTitle = display.bookTitle
    }
}

/// Wraps AlarmKit: authorization, scheduling each alarm from its `Schedule`, cancelling, stopping,
/// and surfacing the "alarm is ringing" event to the `SessionCoordinator`.
///
/// **Per-alarm reconciliation.** Each enabled alarm becomes one native repeating weekly alarm, its
/// ids tracked under its owner (`Schedule.id`) in `AlarmChain`. `reconcile` arms/refreshes enabled
/// alarms and cancels disabled/deleted ones *without* a global teardown — so editing or toggling
/// one alarm never disturbs another, and the alarm currently being handled is left untouched.
@MainActor @Observable
final class AlarmScheduler {

    private let manager = AlarmManager.shared
    private(set) var authorization: AlarmManager.AuthorizationState = .notDetermined

    /// Invoked on every alarm-update tick with the ids currently alerting.
    var onUpdate: (([UUID]) -> Void)?

    /// Every alarm id AlarmKit currently reports (any state), kept fresh from the update stream so
    /// the orphan sweep can clear untracked alarms.
    private var liveAlarmIDs: Set<UUID> = []

    /// Serializes scheduling ops so two overlapping runs can't interleave their cancel/schedule
    /// steps (which used to leak untracked alarms).
    private var opChain: Task<Void, Never>?

    // MARK: Authorization

    func refreshAuthorization() {
        authorization = manager.authorizationState
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BOOKGATE_NO_ALARMKIT"] == "1" { return false }
        #endif
        switch manager.authorizationState {
        case .authorized:
            authorization = .authorized
            return true
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                authorization = state
                return state == .authorized
            } catch {
                return false
            }
        default:
            authorization = manager.authorizationState
            return false
        }
    }

    // MARK: Reconciliation

    private func serialize(_ op: @escaping @MainActor () async -> Void) async {
        let previous = opChain
        let task = Task { @MainActor in
            await previous?.value
            await op()
        }
        opChain = task
        await task.value
    }

    /// Bring AlarmKit in line with the current alarm list: arm/refresh every enabled alarm, cancel
    /// every disabled or deleted one, and sweep orphans — all per owner, never a global nuke. The
    /// `firing` owner (the alarm actively being handled) is skipped so its re-ring chain / watchdog
    /// survive. Cheap, idempotent, serialized.
    func reconcile(_ alarms: [Schedule], excludingFiringOwner firing: UUID? = nil) async {
        await serialize { [weak self] in await self?.performReconcile(alarms, firing: firing) }
    }

    private func performReconcile(_ alarms: [Schedule], firing: UUID?) async {
        let enabled = alarms.filter { $0.isOn && !Self.weekdays(from: $0.days).isEmpty && $0.id != firing }
        let desiredOwners = Set(enabled.map(\.id))

        for owner in AlarmChain.owners() where owner != firing && !desiredOwners.contains(owner) {
            await cancel(owner: owner)
            clearSignature(owner)
        }

        for schedule in enabled {
            let sig = signature(for: schedule)
            if AlarmChain.groupIDs(schedule.id).isEmpty || storedSignature(schedule.id) != sig {
                await baseline(owner: schedule)
                setSignature(schedule.id, sig)
            }
        }

        let tracked = Set(AlarmChain.allTrackedIDs())
        for id in liveAlarmIDs where !tracked.contains(id) {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
    }

    /// Arm the stall watchdog for the firing alarm: re-establish its clean baseline and add ONE
    /// real alarm `seconds` out that fires if the user goes idle on the gate/session screen. Only
    /// this owner is touched.
    func armWatchdog(after seconds: TimeInterval, owner schedule: Schedule) async {
        await serialize { [weak self] in
            guard let self else { return }
            await self.baseline(owner: schedule)
            guard self.authorization == .authorized else { return }
            let countdown = Alarm.CountdownDuration(preAlert: seconds, postAlert: nil)
            await AlarmChain.scheduleRing(owner: schedule.id,
                                          countdown: countdown,
                                          nextCount: 1,
                                          display: Self.display(schedule))
        }
    }

    /// Tear down the firing alarm's watchdog + any stray re-rings, keeping only its repeating alarm
    /// for future nights. Only this owner is touched.
    func disarmWatchdog(owner schedule: Schedule) async {
        await serialize { [weak self] in
            await self?.baseline(owner: schedule)
        }
    }

    /// Cancel one owner's alarms and re-arm a single repeating weekly alarm at its reading time.
    /// No-op arm if the alarm is off, has no active nights, or we're unauthorized.
    private func baseline(owner schedule: Schedule) async {
        await cancel(owner: schedule.id)

        guard schedule.isOn else { return }
        let weekdays = Self.weekdays(from: schedule.days)
        guard !weekdays.isEmpty else { return }
        guard await requestAuthorization() else { return }

        // Only clamp to a valid minute-of-day — reading alarms are evening/any-time, no band.
        let readingMin = min(max(schedule.readingMin, Schedule.readingRange.lowerBound),
                             Schedule.readingRange.upperBound)
        let time = Alarm.Schedule.Relative.Time(hour: readingMin / 60, minute: readingMin % 60)
        let relative = Alarm.Schedule.Relative(time: time, repeats: .weekly(weekdays))
        await AlarmChain.scheduleRing(owner: schedule.id,
                                      schedule: .relative(relative),
                                      nextCount: 1,
                                      display: Self.display(schedule))
    }

    private func cancel(owner: UUID) async {
        for id in AlarmChain.groupIDs(owner) {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
        AlarmChain.clearGroup(owner)
    }

    /// Full reset: cancel every owner's alarms and everything AlarmKit reports.
    func cancelAll() async {
        for owner in AlarmChain.owners() {
            await cancel(owner: owner)
            clearSignature(owner)
        }
        for id in liveAlarmIDs {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
    }

    // MARK: On-device test

    #if DEBUG
    /// Schedule a one-off ring ~`seconds` out — same Snooze-re-rings / Show-My-Book flow as a real
    /// alarm — for on-device testing, independent of active nights. `#if DEBUG` only.
    func scheduleTestAlarm(for schedule: Schedule, in seconds: TimeInterval = 20) async -> String {
        guard await requestAuthorization() else {
            return "Alarm permission is \(Self.describe(authorization)). Enable it in iOS Settings › BookGate (allow Alarms), then try again."
        }
        let countdown = Alarm.CountdownDuration(preAlert: seconds, postAlert: nil)
        guard await AlarmChain.scheduleRing(owner: schedule.id,
                                            countdown: countdown,
                                            nextCount: 1,
                                            display: Self.display(schedule)) != nil else {
            return "❌ Couldn't schedule the alarm — check the Alarms permission."
        }
        return "✅ Rings in \(Int(seconds))s. Lock the phone. Snooze → it returns every \(Int(AlarmChain.reRingSpacing))s (this alarm only); tap “Show My Book” to open the reading gate."
    }
    #endif

    private static func describe(_ state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "not determined"
        @unknown default: return "unknown"
        }
    }

    // MARK: Ringing observation

    func observeUpdates() async {
        for await alarms in manager.alarmUpdates {
            liveAlarmIDs = Set(alarms.map(\.id))
            let alerting = alarms.filter { $0.state == .alerting }.map(\.id)
            onUpdate?(alerting)
        }
    }

    // MARK: Helpers

    static func weekdays(from days: [Bool]) -> [Locale.Weekday] {
        let order: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday,
                                       .friday, .saturday, .sunday]
        return zip(order, days).compactMap { $1 ? $0 : nil }
    }

    /// The display bits AlarmKit shows (also cached for background re-rings). Purely cosmetic.
    /// The book title is injected by `AppServices` via `bookTitleProvider`; empty when none.
    private static func display(_ s: Schedule) -> AlarmChain.RingDisplay {
        AlarmChain.RingDisplay(bookTitle: bookTitleProvider?() ?? "")
    }

    /// Supplies the current book's title for the alert. Set by `AppServices` once the `BookStore`
    /// exists, so the scheduler stays free of book dependencies.
    nonisolated(unsafe) static var bookTitleProvider: (() -> String)?

    // MARK: Per-owner schedule signature (skip re-arming unchanged alarms)

    private static func sigKey(_ owner: UUID) -> String { "bookgate.alarm.sig.\(owner.uuidString)" }

    private func signature(for s: Schedule) -> String {
        let days = s.days.map { $0 ? "1" : "0" }.joined()
        return "\(s.readingMin)|\(days)|\(s.isOn ? 1 : 0)"
    }
    private func storedSignature(_ owner: UUID) -> String? {
        UserDefaults.standard.string(forKey: Self.sigKey(owner))
    }
    private func setSignature(_ owner: UUID, _ sig: String) {
        UserDefaults.standard.set(sig, forKey: Self.sigKey(owner))
    }
    private func clearSignature(_ owner: UUID) {
        UserDefaults.standard.removeObject(forKey: Self.sigKey(owner))
    }
}
