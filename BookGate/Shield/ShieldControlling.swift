import Foundation

/// The seam the session flow uses to raise and lower the app shield, so the night flow can be built
/// and run before Family Controls is wired. Task #6 provides the real `ShieldManager`
/// (ManagedSettingsStore + DeviceActivity); until the entitlement lands, `NoopShield` is injected
/// and sessions run unshielded without breaking the flow.
///
/// Scope (handoff): selected apps are locked from the reading-window start until the daily session
/// is completed, then unlocked; re-locked next night. A lapsed subscription ⇒ shield OFF.
@MainActor
protocol ShieldControlling: AnyObject {
    /// How many apps/categories are currently selected to shield (0 → none chosen yet).
    var shieldedCount: Int { get }
    /// Raise the shield for the reading window (session start).
    func beginReadingWindow()
    /// Lower the shield (session completed, or lapsed/bailed).
    func endReadingWindow()
}

/// No-op shield used until the Family Controls entitlement is granted (task #6). Keeps the session
/// flow fully functional — it simply doesn't lock anything.
@MainActor
final class NoopShield: ShieldControlling {
    var shieldedCount: Int { 0 }
    func beginReadingWindow() {}
    func endReadingWindow() {}
}
