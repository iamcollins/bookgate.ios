import XCTest
@testable import BookGate

/// The streak rules, as Settings states them to the user.
///
/// Settings promises two things in writing — the step-up offer, and **"One rest day a week: a
/// missed night keeps your streak, once every seven days."** The second one was not implemented:
/// any missed night reset the streak to 1. These cases pin the promise to the engine.
@MainActor
final class ProgressRulesTests: XCTestCase {

    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
    }

    /// Reading on consecutive nights just counts up.
    func testConsecutiveNightsAdvanceTheStreak() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-2))
        p.recordSession(minutes: 10, elapsed: 600, now: day(-1))
        p.recordSession(minutes: 10, elapsed: 600, now: day(0))
        XCTAssertEqual(p.currentStreak, 3)
    }

    /// Twice in one night is still one night for the streak — and both sittings for the time.
    func testTwoSessionsInOneNightCountOnceButAddTheirMinutes() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-1))
        p.recordSession(minutes: 10, elapsed: 600, now: day(0))
        p.recordSession(minutes: 20, elapsed: 1200, now: day(0))
        XCTAssertEqual(p.currentStreak, 2)
        XCTAssertEqual(p.minutes(on: day(0)), 30,
                       "both sittings are time read; keeping only the longest lost the extra one")
    }

    /// One missed night is forgiven — the rule Settings states.
    func testOneMissedNightIsForgivenByTheRestDay() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-3))
        p.recordSession(minutes: 10, elapsed: 600, now: day(-2))
        // day(-1) missed
        p.recordSession(minutes: 10, elapsed: 600, now: day(0))
        XCTAssertEqual(p.currentStreak, 3, "a single missed night must not reset the streak")
        XCTAssertFalse(p.restDayAvailable(on: day(0)), "the rest day is now spent")
    }

    /// A second missed night inside the same week is not forgiven.
    func testASecondRestDayInTheSameWeekIsNotGranted() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-6))
        p.recordSession(minutes: 10, elapsed: 600, now: day(-4))   // first miss, forgiven
        XCTAssertEqual(p.currentStreak, 2)
        p.recordSession(minutes: 10, elapsed: 600, now: day(-2))   // second miss, same week
        XCTAssertEqual(p.currentStreak, 1, "only one rest day every seven days")
    }

    /// After a full week the rest day comes back.
    func testTheRestDayReturnsAfterSevenDays() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-20))
        p.recordSession(minutes: 10, elapsed: 600, now: day(-18))  // forgiven
        XCTAssertTrue(p.restDayAvailable(on: day(-10)), "a week later it is available again")
    }

    /// Two missed nights break it — the rule is one night, not a free pass.
    func testTwoMissedNightsBreakTheStreak() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-4))
        p.recordSession(minutes: 10, elapsed: 600, now: day(-3))
        // day(-2) and day(-1) missed
        p.recordSession(minutes: 10, elapsed: 600, now: day(0))
        XCTAssertEqual(p.currentStreak, 1)
    }

    /// The streak shown today stands while the rest day is being spent, and is gone after that.
    func testLiveStreakDuringAndAfterARestDay() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-2))
        XCTAssertEqual(p.liveStreak(on: day(0)), 1, "one night missed, rest day in hand")
        XCTAssertTrue(p.onRestDay)
        XCTAssertEqual(p.liveStreak(on: day(1)), 0, "two nights missed — the streak is gone")
    }

    /// Yesterday still counts as an unbroken streak.
    func testLiveStreakHoldsWhenYesterdayWasRead() {
        let p = ProgressStore()
        p.recordSession(minutes: 10, elapsed: 600, now: day(-1))
        XCTAssertEqual(p.liveStreak(on: day(0)), 1)
        XCTAssertFalse(p.onRestDay)
    }
}
