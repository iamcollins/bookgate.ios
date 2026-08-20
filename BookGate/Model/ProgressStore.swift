import Foundation
import Observation

/// The streak / progress model behind the session-complete screen and the Progress heatmap.
///
/// Persisted as one Codable snapshot in UserDefaults. Beyond the scalar streak it keeps a **log of
/// each night read and how long** — `nights[startOfDay] = minutes` — which powers the heatmap
/// (fill weight = session length) and the total-time fact. Progress shows exactly three facts:
/// streak, current month, total time.
@MainActor @Observable
final class ProgressStore {

    private(set) var currentStreak = 0
    private(set) var bestStreak = 0
    private(set) var lastReadDay: Date?

    /// Each calendar night read (start-of-day) → minutes of that session. The heatmap reads both
    /// the set of keys (which nights) and the values (fill weight).
    private(set) var nights: [Date: Int] = [:]

    /// Elapsed seconds of the most recent completed session, for the complete screen.
    private(set) var lastElapsed: TimeInterval = 0

    private static let key = "bookgate.progress.v1"

    /// Distinct nights read, all-time.
    var totalNights: Int { nights.count }
    /// Total minutes read, all-time.
    var totalMinutes: Int { nights.values.reduce(0, +) }

    /// The streak as it stands *today*: the stored streak is only advanced at completion and never
    /// decayed, so a streak whose last night is older than yesterday is already broken — surface 0.
    var liveStreak: Int {
        guard let last = lastReadDay else { return 0 }
        let cal = Calendar.current
        let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last),
                                     to: cal.startOfDay(for: .now)).day ?? 99
        return gap <= 1 ? currentStreak : 0
    }

    /// Whether a session was completed today.
    var readToday: Bool {
        guard let last = lastReadDay else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// Whether yesterday was missed (but the streak isn't freshly today) — drives Today's calm
    /// "missed yesterday" copy. No red, no reset drama.
    var missedYesterday: Bool {
        guard let last = lastReadDay else { return false }
        let cal = Calendar.current
        let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last),
                                     to: cal.startOfDay(for: .now)).day ?? 99
        return gap >= 2
    }

    /// Record a completed reading session. Streak advances once per calendar day.
    func recordNight(minutes: Int, elapsed: TimeInterval, now: Date = .now) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: now)
        lastElapsed = elapsed
        nights[day] = max(nights[day] ?? 0, minutes)

        if let last = lastReadDay {
            if cal.isDate(last, inSameDayAs: now) {
                // Already counted today — keep the streak.
            } else if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
                      cal.isDate(last, inSameDayAs: yesterday) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        bestStreak = max(bestStreak, currentStreak)
        lastReadDay = now
        save()
    }

    /// Minutes read on a given calendar day, or nil if none.
    func minutes(on day: Date) -> Int? {
        nights[Calendar.current.startOfDay(for: day)]
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var currentStreak: Int
        var bestStreak: Int
        var lastReadDay: Date?
        var lastElapsed: TimeInterval
        var nightDays: [Date]
        var nightMinutes: [Int]
    }

    #if DEBUG
    /// Populate a realistic streak + heatmap history for screenshots (BOOKGATE_SEED_PROGRESS).
    /// In-memory only — never saved.
    /// - Parameter includeToday: when false the streak runs up to *yesterday*, leaving tonight
    ///   unread — the state Today is designed around (its one primary action). The screenshot
    ///   harness seeds it that way; a day already ticked off demotes that button.
    func debugSeed(currentStreak cs: Int = 17, bestStreak bs: Int = 31, includeToday: Bool = true) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let last = includeToday ? today : cal.date(byAdding: .day, value: -1, to: today) ?? today
        currentStreak = cs
        bestStreak = bs
        lastReadDay = last
        lastElapsed = 15 * 60
        let lengths = [5, 10, 15, 20, 30, 45]
        var map: [Date: Int] = [:]
        for i in 0..<cs {
            if let d = cal.date(byAdding: .day, value: -i, to: last) { map[d] = lengths[i % lengths.count] }
        }
        for i in cs..<80 where (i * 7) % 11 < 5 {
            if let d = cal.date(byAdding: .day, value: -i, to: last) { map[d] = lengths[i % lengths.count] }
        }
        nights = map
    }
    #endif

    static func load() -> ProgressStore {
        let store = ProgressStore()
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return store }
        store.currentStreak = snap.currentStreak
        store.bestStreak = snap.bestStreak
        store.lastReadDay = snap.lastReadDay
        store.lastElapsed = snap.lastElapsed
        store.nights = Dictionary(uniqueKeysWithValues:
            zip(snap.nightDays, snap.nightMinutes))
        return store
    }

    private func save() {
        let days = Array(nights.keys)
        let snap = Snapshot(currentStreak: currentStreak, bestStreak: bestStreak,
                            lastReadDay: lastReadDay, lastElapsed: lastElapsed,
                            nightDays: days, nightMinutes: days.map { nights[$0] ?? 0 })
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
