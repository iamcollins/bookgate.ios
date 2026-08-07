import ManagedSettings
import Foundation

/// Handles taps on the shield barrier's two buttons. **Return to BookGate** closes the shielded app;
/// **Emergency access** lets the user through — the shield always offers a way out, never a trap.
///
/// Not compiled into the app target yet — see ../README.md.
final class ReadingShieldAction: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:   return .close   // Return to BookGate → close the distracting app
        case .secondaryButtonPressed: return .none    // Emergency access → allow through this time
        @unknown default:             return .close
        }
    }
}
