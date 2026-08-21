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

    private func makeCoordinator(shield: ShieldControlling,
                                 length: Int = 20) -> (SessionCoordinator, ReadingSettings) {
        let settings = ReadingSettings()
        settings.defaultLength = length
        let coordinator = SessionCoordinator(
            scheduleForID: { _ in nil },
            progress: ProgressStore(),
            journal: JournalStore(),
            books: BookStore(),
            settings: settings,
            scheduler: AlarmScheduler(),
            shield: shield)
        return (coordinator, settings)
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
}
