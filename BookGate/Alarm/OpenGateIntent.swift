import AppIntents
import Foundation

/// Cross-launch signal that the user tapped the alarm's "Show My Book" button, so the app should
/// jump straight into the reading gate (camera) when it opens, rather than sitting on the ringing
/// screen.
enum PendingGate {
    private static let flagKey = "bookgate.pending.gate"
    private static let idKey = "bookgate.pending.alarmID"
    private static let tsKey = "bookgate.pending.ts"

    static func set(alarmID: String) {
        let d = UserDefaults.standard
        d.set(true, forKey: flagKey)
        d.set(alarmID, forKey: idKey)
        d.set(Date().timeIntervalSince1970, forKey: tsKey)
    }

    /// If a *recent* gate is pending, clear and return its alarm id. A stale flag (older than
    /// `maxAge`) is cleared and ignored, so an old tap can't reopen the camera on a later cold
    /// launch.
    static func consume(maxAge: TimeInterval = 120) -> String? {
        let d = UserDefaults.standard
        guard d.bool(forKey: flagKey) else { return nil }
        let id = d.string(forKey: idKey) ?? ""
        let ts = d.double(forKey: tsKey)
        d.removeObject(forKey: flagKey)
        d.removeObject(forKey: idKey)
        d.removeObject(forKey: tsKey)
        guard Date().timeIntervalSince1970 - ts < maxAge else { return nil }
        return id
    }
}

/// The alarm alert's "Show My Book" button. `supportedModes = .foreground` (the iOS 26 replacement
/// for the deprecated `openAppWhenRun`) **launches BookGate** when tapped; `perform` records which
/// alarm fired so the app routes straight into the reading gate (see `SessionCoordinator`).
///
/// `alarmID` carries the owning `Schedule.id` (not an ephemeral ring id), so the app resolves the
/// fired alarm back to its settings.
struct OpenGateIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Show My Book"
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "alarmID")
    var alarmID: String

    init() { self.alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingGate.set(alarmID: alarmID)
        return .result()
    }
}
