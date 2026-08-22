import XCTest
@testable import BookGate

/// What Today calls the next reading session.
///
/// A reading alarm may be set to **any** minute of the day — `Schedule.readingRange` is `0...1439`
/// and always has been. The card, though, said "TONIGHT" unconditionally, so a reader who set
/// 10:00 in the morning was told their morning was a night.
@MainActor
final class ScheduleLabelTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    // MARK: The word

    func testTheWordFollowsTheTimeOfDay() {
        XCTAssertEqual(Schedule.periodLabel(forMinuteOfDay: 6 * 60), "This morning")
        XCTAssertEqual(Schedule.periodLabel(forMinuteOfDay: 10 * 60), "This morning",
                       "10:00 AM is the case that was being announced as TONIGHT")
        XCTAssertEqual(Schedule.periodLabel(forMinuteOfDay: 14 * 60), "This afternoon")
        XCTAssertEqual(Schedule.periodLabel(forMinuteOfDay: 21 * 60), "Tonight")
        XCTAssertEqual(Schedule.periodLabel(forMinuteOfDay: 0), "This morning", "midnight is not tonight")
    }

    // MARK: When it next runs

    func testStillToComeTodayIsToday() {
        let schedule = Schedule()
        schedule.readingMin = 21 * 60
        // Wednesday 12 August 2026, lunchtime.
        let next = schedule.nextOccurrence(after: date(2026, 8, 12, 12, 0), calendar: calendar)
        XCTAssertEqual(next, date(2026, 8, 12, 21, 0))
    }

    func testAlreadyPassedTodayRollsToTomorrow() {
        let schedule = Schedule()
        schedule.readingMin = 10 * 60
        let next = schedule.nextOccurrence(after: date(2026, 8, 12, 15, 0), calendar: calendar)
        XCTAssertEqual(next, date(2026, 8, 13, 10, 0),
                       "a morning alarm read in the afternoon points at tomorrow, not this morning")
    }

    func testInactiveDaysAreSkipped() {
        let schedule = Schedule()
        schedule.readingMin = 21 * 60
        // Mondays only. `days` is Monday-first.
        schedule.days = [true, false, false, false, false, false, false]
        // From Wednesday 12 August 2026 → Monday 17 August.
        let next = schedule.nextOccurrence(after: date(2026, 8, 12, 12, 0), calendar: calendar)
        XCTAssertEqual(next, date(2026, 8, 17, 21, 0))
    }

    func testAnAlarmThatIsOffNeverRuns() {
        let schedule = Schedule()
        schedule.isOn = false
        XCTAssertNil(schedule.nextOccurrence(after: date(2026, 8, 12, 12, 0), calendar: calendar))
    }

    func testNoActiveDaysNeverRuns() {
        let schedule = Schedule()
        schedule.days = Array(repeating: false, count: 7)
        XCTAssertNil(schedule.nextOccurrence(after: date(2026, 8, 12, 12, 0), calendar: calendar))
    }

    // MARK: The scheduled window

    /// Today asks one question of the clock: is right now the session the app asked for, or is it
    /// reading the reader added around it?
    func testInsideTheWindowIsTheScheduledMoment() {
        let schedule = Schedule()
        schedule.readingMin = 21 * 60
        let window = schedule.window(on: date(2026, 8, 12, 12, 0), minutes: 10, calendar: calendar)
        XCTAssertNotNil(window)
        XCTAssertTrue(window!.contains(date(2026, 8, 12, 21, 0)), "the start counts")
        XCTAssertTrue(window!.contains(date(2026, 8, 12, 21, 7)), "arriving a few minutes late counts")
        XCTAssertTrue(window!.contains(date(2026, 8, 12, 21, 10)), "so does the last minute")
    }

    func testOutsideTheWindowIsNotTheScheduledMoment() {
        let schedule = Schedule()
        schedule.readingMin = 21 * 60
        let window = schedule.window(on: date(2026, 8, 12, 12, 0), minutes: 10, calendar: calendar)!
        XCTAssertFalse(window.contains(date(2026, 8, 12, 17, 0)), "hours early is extra reading")
        XCTAssertFalse(window.contains(date(2026, 8, 12, 23, 0)), "and so is hours late")
    }

    /// A night the reader deliberately took off asks for nothing, so nothing is scheduled to be
    /// inside of.
    func testAnInactiveNightHasNoWindow() {
        let schedule = Schedule()
        schedule.days = [true, false, false, false, false, false, false]   // Mondays only
        // 12 August 2026 is a Wednesday.
        XCTAssertNil(schedule.window(on: date(2026, 8, 12, 12, 0), minutes: 10, calendar: calendar))
    }

    func testAnAlarmThatIsOffHasNoWindow() {
        let schedule = Schedule()
        schedule.isOn = false
        XCTAssertNil(schedule.window(on: date(2026, 8, 12, 12, 0), minutes: 10, calendar: calendar))
    }
}
