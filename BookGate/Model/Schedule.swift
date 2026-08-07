import Observation
import SwiftUI

/// One reading alarm: a nightly time, the active nights, and an on/off toggle.
///
/// BookGate normally holds a single reading alarm (the schedule is app-wide, shown in
/// Settings → Reading, not per book), but the engine is list-shaped for reuse from Thrise's
/// proven scheduler. Unlike Thrise's *morning* wake alarm, a reading alarm may be set to **any
/// time** — the 4:00–11:00 AM clamp is intentionally removed (see `readingRange`).
@Observable
final class Schedule {

    /// Stable identity — the join key for persistence, AlarmKit id tracking, and the intents
    /// that resolve a fired alarm back to its settings. Immutable and unobserved.
    let id: UUID

    /// Whether this alarm is armed. Off keeps its settings but schedules nothing. Persists via
    /// `onChange`; the caller must also `resync()` so AlarmKit arms/disarms it.
    var isOn: Bool = true { didSet { onChange?() } }

    /// Reading time in minutes past midnight. Default 9:00 PM. Reading is evening/any-time, so
    /// the only clamp is to a valid minute-of-day (0…1439) — never a wall-clock band.
    var readingMin: Int = 1260 {                               // 9:00 PM
        didSet {
            let c = min(max(readingMin, Self.readingRange.lowerBound), Self.readingRange.upperBound)
            if c != readingMin { readingMin = c; return }      // correct, then fall through once
            onChange?()
        }
    }

    /// Active nights, Monday-first. Default every night — reading is a nightly habit; a "rest
    /// day" simply unchecks one night.
    var days: [Bool] = [true, true, true, true, true, true, true] { didSet { onChange?() } }

    /// Fired whenever a stored value changes so the owner can persist and re-sync the alarm.
    /// Set by `AppServices` *after* loading so hydrating from disk doesn't echo back a save.
    @ObservationIgnored var onChange: (() -> Void)?

    init(id: UUID = UUID()) {
        self.id = id
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let r = env["BOOKGATE_READING"], let v = Int(r) { readingMin = v }
        #endif
    }

    // MARK: Range

    /// Any minute of the day is valid — reading alarms are evening/any-time.
    static let readingRange: ClosedRange<Int> = 0...1439

    // MARK: Formatting

    /// Splits a minute count into a locale-aware time string and an optional day-period marker.
    /// 12-hour locales get `("9:00", "PM")`; 24-hour locales `("21:00", "")` — respecting the
    /// user's locale and 24-hour system setting.
    static func hourMinute(_ minutes: Int, locale: Locale = .current) -> (time: String, marker: String) {
        let m = ((minutes % 1440) + 1440) % 1440
        var comps = DateComponents()
        comps.hour = m / 60
        comps.minute = m % 60
        let date = Calendar.current.date(from: comps) ?? Date(timeIntervalSinceReferenceDate: 0)

        let df = DateFormatter()
        df.locale = locale
        if uses12HourClock(locale) {
            df.setLocalizedDateFormatFromTemplate("a")
            let marker = df.string(from: date)
            df.setLocalizedDateFormatFromTemplate("hmm")
            let time = df.string(from: date)
                .replacingOccurrences(of: marker, with: "")
                .trimmingCharacters(in: .whitespaces)
            return (time, marker)
        } else {
            df.setLocalizedDateFormatFromTemplate("Hmm")       // 21:00
            return (df.string(from: date), "")
        }
    }

    private static func uses12HourClock(_ locale: Locale) -> Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "H"
        return pattern.contains("a")
    }

    /// A compact `9:00 PM` string for the current locale (marker appended where used).
    var timeLabel: String {
        let (t, m) = Self.hourMinute(readingMin)
        return m.isEmpty ? t : "\(t) \(m)"
    }

    /// The schedule summary label derived from the active nights.
    var dayLabel: String {
        let on = days.enumerated().filter { $0.element }.map { $0.offset }
        if on.isEmpty { return String(localized: "Off", comment: "Alarm has no active nights") }
        if on.count == 7 { return String(localized: "Every night", comment: "Alarm repeats nightly") }
        if on == [0, 1, 2, 3, 4] { return String(localized: "Weeknights", comment: "Mon–Fri") }
        if on == [5, 6] { return String(localized: "Weekends", comment: "Sat–Sun") }
        return on.map { Self.shortDayNames[$0] }.formatted(.list(type: .and, width: .short))
    }

    /// Abbreviated weekday names, Monday-first, localized.
    static var shortDayNames: [String] { mondayFirst(Calendar.current.shortStandaloneWeekdaySymbols) }
    /// Single-letter day markers, Monday-first, localized.
    static var dayLetters: [String] { mondayFirst(Calendar.current.veryShortStandaloneWeekdaySymbols) }

    private static func mondayFirst(_ symbols: [String]) -> [String] {
        guard symbols.count == 7 else { return symbols }
        return (1...7).map { symbols[$0 % 7] }
    }
}
