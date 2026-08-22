import Foundation
import Observation
import FamilyControls
import ManagedSettings

/// The real app shield, built on Family Controls + ManagedSettings. Conforms to `ShieldControlling`
/// so the session flow drives it unchanged.
///
/// **Entitlement-gated by design.** `com.apple.developer.family-controls` is being requested
/// separately; until it lands, `requestAuthorization()` fails and every shield op is a safe no-op —
/// the app builds, runs, and simply doesn't lock anything (shield OFF). The moment the entitlement
/// is granted and the user authorizes, the exact same code starts locking. A lapsed subscription
/// also forces shield OFF (the caller stops raising the window).
///
/// The `DeviceActivityMonitor` and custom `ShieldConfiguration` extensions live in
/// `BookGate-Extensions/` (not compiled into the app target yet — see that folder's README); they
/// attach as app-extension targets when the entitlement is available.
@MainActor @Observable
final class ShieldManager: ShieldControlling {

    /// The apps/categories the user chose to shield. Bound by the FamilyActivityPicker.
    var selection = FamilyActivitySelection() {
        didSet { persist() }
    }

    private(set) var authorized = false

    private let store = ManagedSettingsStore(named: .init(rawValue: "bookgate.reading"))
    private static let selectionKey = "bookgate.shield.selection.v1"

    init() {
        loadSelection()
        refreshAuthorization()
    }

    var shieldedCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    // MARK: Authorization

    func refreshAuthorization() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Request Screen Time authorization. Throws/no-ops cleanly without the entitlement.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            authorized = false
        }
        return authorized
    }

    /// Authorization, but for the picker's sake — approved already, or ask now.
    ///
    /// `FamilyActivityPicker` draws its category shells whether or not the app has Screen Time
    /// access, and expanding one without it shows nothing at all. So the picker must never be
    /// opened before this returns true, or the reader is handed an empty list with no explanation.
    @discardableResult
    func authorizeForPicker() async -> Bool {
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            authorized = true
            return true
        }
        return await requestAuthorization()
    }

    // MARK: Shield lifecycle

    /// Raise the shield for the reading window. No-op without authorization or an empty selection.
    func beginReadingWindow() {
        guard authorized, shieldedCount > 0 else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    /// Lower the shield (session completed, bailed, or lapsed).
    func endReadingWindow() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: Self.selectionKey)
        }
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: Self.selectionKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        // Assign without echoing a save.
        let s = decoded
        selection = s
    }
}
