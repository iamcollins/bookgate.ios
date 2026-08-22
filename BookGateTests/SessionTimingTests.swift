import XCTest
@testable import BookGate

/// A shielded reading session records a spy's calls so the test can assert the shield's lifecycle.
@MainActor
private final class SpyShield: ShieldControlling {
    var shieldedCount: Int { 3 }
    private(set) var raised = 0
    private(set) var lowered = 0
    func beginReadingWindow() { raised += 1 }
    func endReadingWindow() { lowered += 1 }
}

/// Session timing and the shield lifecycle.
///
/// The session used to be counted by a `Task.sleep(1s)` loop, which is suspended the moment the app
/// is backgrounded — and this app is *designed* to be put down while you read a paper book. A
/// twenty-minute session left running in a pocket came back reading twenty minutes left. The clock
/// is now anchored to two dates, and `syncClock` is what every foreground calls.
@MainActor
final class SessionTimingTests: XCTestCase {

    private var suites: [UserDefaults] = []

    override func tearDown() {
        for suite in suites { suite.removePersistentDomain(forName: suite.description) }
        suites = []
        super.tearDown()
    }

    /// A store of its own per test. The restore runs in `init`, so a shared one would hand one
    /// test's running session to the next.
    private func isolatedDefaults() -> UserDefaults {
        let name = "test.session.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suites.append(suite)
        return suite
    }

    private var lastProgress = ProgressStore()

    private func makeCoordinator(shield: ShieldControlling,
                                 length: Int = 20,
                                 defaults: UserDefaults? = nil) -> (SessionCoordinator, ReadingSettings) {
        let settings = ReadingSettings()
        settings.defaultLength = length
        lastProgress = ProgressStore()
        let coordinator = SessionCoordinator(
            scheduleForID: { _ in nil },
            progress: lastProgress,
            journal: JournalStore(),
            books: BookStore(),
            settings: settings,
            scheduler: AlarmScheduler(),
            shield: shield,
            defaults: defaults ?? isolatedDefaults())
        return (coordinator, settings)
    }

    // MARK: Surviving a restart

    /// iOS reclaims a backgrounded app routinely. The rebuilt process used to come back at `.idle`
    /// — Today offering "Start Reading" with minutes still to run — because nothing about the
    /// session was written down.
    func testARunningSessionSurvivesTheProcessBeingKilled() {
        let store = isolatedDefaults()
        let start = Date().addingTimeInterval(-6 * 60)          // started six minutes ago
        let (first, _) = makeCoordinator(shield: SpyShield(), length: 20, defaults: store)
        first.startSession(now: start)

        // The process dies and a fresh coordinator is built against the same store.
        let (restored, _) = makeCoordinator(shield: SpyShield(), length: 20, defaults: store)

        XCTAssertEqual(restored.phase, .session, "the session must come back, not vanish")
        XCTAssertEqual(restored.sessionLengthMinutes, 20)
        XCTAssertEqual(Double(restored.secondsLeft), 14 * 60, accuracy: 2,
                       "and it must resume where the wall clock says, not where it started")
    }

    /// Last night's session must never reappear on top of tonight — and dropping it is the only
    /// moment anything still knows a reading window was opened, so that is where the shield
    /// comes down.
    func testAStaleSessionIsDiscardedAndLowersTheShield() {
        let store = isolatedDefaults()
        let (first, _) = makeCoordinator(shield: SpyShield(), length: 20, defaults: store)
        first.startSession(now: Date().addingTimeInterval(-9 * 60 * 60))   // last night

        let shield = SpyShield()
        let (restored, _) = makeCoordinator(shield: shield, length: 20, defaults: store)

        XCTAssertEqual(restored.phase, .idle, "a session from hours ago is not tonight's")
        XCTAssertEqual(shield.lowered, 1,
                       "the shield outlives the process — something has to take it down")
    }

    /// Finishing clears the record, so the next launch is a clean one.
    func testEndingEarlyLeavesNothingToRestore() {
        let store = isolatedDefaults()
        let (first, _) = makeCoordinator(shield: SpyShield(), length: 20, defaults: store)
        first.startSession(now: Date())
        first.endEarly()

        let (restored, _) = makeCoordinator(shield: SpyShield(), length: 20, defaults: store)
        XCTAssertEqual(restored.phase, .idle)
    }

    /// The clock is read off the wall, not off how many ticks the app got to run.
    func testTimeLeftIsDerivedFromTheWallClock() {
        let (session, _) = makeCoordinator(shield: SpyShield())
        let start = Date()
        session.startSession(now: start)
        XCTAssertEqual(session.secondsLeft, 20 * 60)

        // Simulate five minutes passing while the app was suspended: no ticks ran at all.
        session.syncClock(now: start.addingTimeInterval(5 * 60))
        XCTAssertEqual(session.secondsLeft, 15 * 60,
                       "a suspended app must come back to the right time, not the time it left")
    }

    /// Coming back after the goal has passed finds the goal reached, not a stalled countdown.
    func testGoalIsReachedWhileSuspended() {
        let (session, _) = makeCoordinator(shield: SpyShield(), length: 5)
        let start = Date()
        session.startSession(now: start)
        XCTAssertFalse(session.goalReached)

        session.syncClock(now: start.addingTimeInterval(6 * 60))
        XCTAssertEqual(session.secondsLeft, 0)
        XCTAssertTrue(session.goalReached)
        XCTAssertEqual(session.remainingFraction, 0, "the lamp is out at the goal")
    }

    /// The lamp's fraction tracks the wall clock across the whole session.
    func testRemainingFractionTracksTheClock() {
        let (session, _) = makeCoordinator(shield: SpyShield(), length: 10)
        let start = Date()
        session.startSession(now: start)
        XCTAssertEqual(session.remainingFraction, 1, accuracy: 0.01)

        session.syncClock(now: start.addingTimeInterval(5 * 60))
        XCTAssertEqual(session.remainingFraction, 0.5, accuracy: 0.02)
    }

    /// Overtime counts up from the moment it was chosen, also on the wall clock.
    func testOvertimeCountsUpOnTheWallClock() {
        let (session, _) = makeCoordinator(shield: SpyShield(), length: 5)
        let start = Date()
        session.startSession(now: start)
        let atGoal = start.addingTimeInterval(5 * 60)
        session.syncClock(now: atGoal)

        session.keepReading(now: atGoal)
        XCTAssertTrue(session.inOvertime)
        XCTAssertEqual(session.overtimeSecs, 0)

        session.syncClock(now: atGoal.addingTimeInterval(90))
        XCTAssertEqual(session.overtimeSecs, 90)
    }

    /// The shield goes up at the start and comes down when the night is recorded.
    func testShieldIsRaisedForTheSessionAndLoweredOnFinish() {
        let shield = SpyShield()
        let (session, _) = makeCoordinator(shield: shield)
        session.startSession()
        XCTAssertEqual(shield.raised, 1)
        XCTAssertEqual(shield.lowered, 0)

        session.finishSession()
        XCTAssertEqual(shield.lowered, 1, "a finished session must never leave apps locked")
        XCTAssertEqual(session.phase, .complete)
    }

    /// Bailing out early also lowers the shield — the one path that must not strand the user.
    func testEndingEarlyLowersTheShield() {
        let shield = SpyShield()
        let (session, _) = makeCoordinator(shield: shield)
        session.startSession()
        session.endEarly()
        XCTAssertEqual(shield.lowered, 1)
        XCTAssertEqual(session.phase, .idle)
    }

    /// Tonight's override applies to the session and is cleared once the night is recorded.
    func testTonightOverrideAppliesThenClears() {
        let shield = SpyShield()
        let (session, settings) = makeCoordinator(shield: shield, length: 10)
        settings.tonightLength = 30
        session.startSession()
        XCTAssertEqual(session.sessionLengthMinutes, 30)

        session.finishSession()
        XCTAssertNil(settings.tonightLength, "a tonight-only change must not become the default")
        XCTAssertEqual(settings.defaultLength, 10)
    }

    // MARK: What gets written down

    /// The record is the time actually read, not the time scheduled. A ten-minute commitment
    /// carried into overtime is half an hour of reading, and storing ten dropped the rest — out
    /// of the heatmap, and out of the total-time fact, which is a sum of exactly these numbers.
    func testOvertimeIsRecorded() {
        let (session, _) = makeCoordinator(shield: SpyShield(), length: 10)
        let start = Date()
        session.startSession(now: start)

        session.syncClock(now: start.addingTimeInterval(10 * 60))       // goal
        session.keepReading(now: start.addingTimeInterval(10 * 60))
        session.syncClock(now: start.addingTimeInterval(25 * 60))       // 15 more
        session.finishSession()

        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(lastProgress.minutes(on: today), 25,
                       "ten scheduled plus fifteen of overtime is twenty-five minutes read")
    }

    /// A second sitting adds its time and leaves the streak alone — reading more is a quantity,
    /// keeping the habit is not.
    func testASecondSittingAddsTimeButNotAStreakNight() {
        let (first, _) = makeCoordinator(shield: SpyShield(), length: 10)
        let progress = lastProgress
        first.startSession(now: Date())
        first.syncClock(now: Date().addingTimeInterval(10 * 60))
        first.finishSession()
        let streakAfterFirst = progress.currentStreak

        progress.recordSession(minutes: 20, elapsed: 20 * 60)

        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(progress.minutes(on: today), 30)
        XCTAssertEqual(progress.currentStreak, streakAfterFirst, "one night, however many sittings")
    }
}
