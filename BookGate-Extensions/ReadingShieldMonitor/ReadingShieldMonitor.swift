import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

/// DeviceActivityMonitor extension: raises the shield at the reading-window start (the alarm time)
/// and lifts it when the window ends — so apps are locked from the window start even if BookGate is
/// closed. The app also lifts the shield the moment the session completes (see `ShieldManager`).
///
/// Not compiled into the app target yet — see ../README.md. Reads the user's selection from the
/// shared App Group (add `group.app.bookgate.shared` and switch the suite name when wiring up).
final class ReadingShieldMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init(rawValue: "bookgate.reading"))
    private static let suite = "group.app.bookgate.shared"           // TODO(entitlement): add App Group
    private static let selectionKey = "bookgate.shield.selection.v1"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let selection = loadSelection() else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: Self.suite),
              let data = defaults.data(forKey: Self.selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
