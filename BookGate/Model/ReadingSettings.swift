import Foundation
import Observation

/// App-wide reading preferences. **Session length is one app-wide setting, not per book** (handoff
/// rule 1): asked once at first open (5 min preselected), permanent home is Settings → Reading; the
/// nightly sheet overrides *tonight only*. Persisted as scalars in UserDefaults.
@MainActor @Observable
final class ReadingSettings {

    /// The seven offered durations, in minutes. 1h is present but plainly the outlier.
    static let lengthOptions = [5, 10, 15, 20, 30, 45, 60]

    /// App-wide default session length (minutes). Default 5 (preselected, RECOMMENDED).
    var defaultLength: Int = 5 { didSet { persist(\.defaultLength, defaultLength, Keys.defaultLength) } }

    /// Overrides tonight only; cleared after the session runs. `nil` = use `defaultLength`.
    var tonightLength: Int? = nil { didSet { persistOptional(tonightLength, Keys.tonightLength) } }

    /// Theme preference (ignored by the night flow, which is always dark).
    var theme: ThemePreference = .system {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// The length that applies to tonight's session.
    var effectiveTonightLength: Int { tonightLength ?? defaultLength }

    /// The next length up from the current default, or nil at the ceiling (60).
    var nextLengthUp: Int? {
        guard let i = Self.lengthOptions.firstIndex(of: defaultLength),
              i + 1 < Self.lengthOptions.count else { return nil }
        return Self.lengthOptions[i + 1]
    }

    // MARK: Step-up bookkeeping — "the default earns its way up" (handoff rule 2)

    /// ISO year-week in which the step-up was last offered/declined, so it isn't asked again that
    /// week after a decline.
    var stepUpHandledWeek: String? = nil {
        didSet { persistOptional(stepUpHandledWeek, Keys.stepUpWeek) }
    }

    /// Current ISO year-week string, e.g. "2026-W32".
    static func currentWeek(_ now: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }

    /// Whether the step-up prompt may be shown this week (not already handled, and there's room to
    /// grow). The *clean-week* condition is evaluated separately by the caller.
    func mayOfferStepUp(now: Date = .now) -> Bool {
        nextLengthUp != nil && stepUpHandledWeek != Self.currentWeek(now)
    }

    /// Clear the tonight override once the session is done.
    func clearTonightOverride() { tonightLength = nil }

    // MARK: Persistence

    private enum Keys {
        static let defaultLength = "bookgate.settings.defaultLength"
        static let tonightLength = "bookgate.settings.tonightLength"
        static let theme = "bookgate.settings.theme"
        static let stepUpWeek = "bookgate.settings.stepUpWeek"
    }

    private func persist(_ keyPath: KeyPath<ReadingSettings, Int>, _ value: Int, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func persistOptional(_ value: Int?, _ key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
    private func persistOptional(_ value: String?, _ key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    static func load() -> ReadingSettings {
        let s = ReadingSettings()
        let d = UserDefaults.standard
        s.apply {
            if d.object(forKey: Keys.defaultLength) != nil { $0.defaultLength = d.integer(forKey: Keys.defaultLength) }
            if d.object(forKey: Keys.tonightLength) != nil { $0.tonightLength = d.integer(forKey: Keys.tonightLength) }
            if let t = d.string(forKey: Keys.theme), let pref = ThemePreference(rawValue: t) { $0.theme = pref }
            $0.stepUpHandledWeek = d.string(forKey: Keys.stepUpWeek)
        }
        return s
    }

    /// Mutate without echoing writes back to UserDefaults during hydration.
    private func apply(_ body: (ReadingSettings) -> Void) {
        // didSet observers still fire, but they write the same value we just read — harmless and
        // idempotent. Kept as a seam in case load grows.
        body(self)
    }
}
