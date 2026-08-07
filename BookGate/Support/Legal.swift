import Foundation

/// The app's public legal links, in one place. App Review requires functional
/// Terms of Use (EULA) and Privacy Policy links on any auto-renewable
/// subscription paywall, and the app-wide settings screen links them too.
enum Legal {
    // TODO: confirm BookGate legal URLs
    static let termsURL = URL(string: "https://bookgate.app/terms")!
    // TODO: confirm BookGate legal URLs
    static let privacyURL = URL(string: "https://bookgate.app/privacy")!
}
