import Foundation
import StoreKit
import SubscriptionKit

/// What StoreKit actually answered, rendered on the paywall when no prices resolved.
///
/// **Deliberately NOT `#if DEBUG`.** The device this app is tested on is reached only through
/// TestFlight — a Release build, with no cable and so no Console logs. Without this the failure is
/// silent on the one machine that matters, and we are left inferring from the outside.
///
/// It answers the questions that separate the plausible causes:
/// - `bundle` — which app record this build belongs to. Products live under an app record; if this
///   is not the record the subscriptions were created under, nothing will ever resolve.
/// - `asked` — the exact ids requested, so a typo or a stale id is visible rather than assumed.
/// - `got` — how many came back. **0 with no error means Apple found no such products for this
///   app**, which is a very different bug from a network failure.
/// - `state` — SubscriptionKit's load state, carrying the underlying error text when there was one.
/// - `storefront` / `env` — which store answered, and whether it was sandbox (TestFlight) or
///   production.
///
/// Remove this, or hide it behind a gesture, before the App Store build. It is a debugging
/// instrument, not a feature.
@MainActor
enum PaywallDiagnostics {

    /// The part that must never be stale: it is read on every render, so it always reflects the
    /// fetch as it stands right now. An earlier version snapshotted this into `@State` and reported
    /// "loading" long after the fetch had failed — which is precisely the lie this panel exists to
    /// prevent.
    static func live(store: SubscriptionStore) -> String {
        var lines = [
            "bundle \(Bundle.main.bundleIdentifier ?? "—")",
            "asked \(store.config.orderedPlanIDs.joined(separator: ", "))",
            "got \(store.products.count) · \(describe(store.productLoadState))",
        ]
        if !store.products.isEmpty {
            lines.append("ids \(store.products.map(\.id).joined(separator: ", "))")
        }
        lines.append("entitlement \(store.entitlement)")
        return lines.joined(separator: "\n")
    }

    /// The part that needs a network round trip, resolved once and appended.
    static func environment() async -> String {
        var lines: [String] = []

        let storefront = await Storefront.current
        lines.append("storefront \(storefront?.countryCode ?? "—") · pay \(AppStore.canMakePayments ? "yes" : "no")")

        // Which store issued this build's receipt: TestFlight is sandbox, the App Store is
        // production. A build asking the wrong catalogue explains an empty result on its own.
        do {
            let result = try await AppTransaction.shared
            if case .verified(let transaction) = result {
                lines.append("env \(transaction.environment.rawValue) · appVersion \(transaction.originalAppVersion)")
            } else {
                lines.append("env unverified")
            }
        } catch {
            lines.append("env unavailable (\(short(error)))")
        }
        return lines.joined(separator: "\n")
    }

    private static func describe(_ state: SubscriptionStore.ProductLoadState) -> String {
        switch state {
        case .idle:            return "idle"
        case .loading:         return "loading"
        case .loaded:          return "loaded"
        case .failed(let error):
            switch error {
            // Empty result, no error: Apple has no such products for this app record.
            case .productsUnavailable: return "failed: none returned"
            case .timedOut:            return "failed: timed out"
            case .underlying(let text): return "failed: \(text.prefix(160))"
            }
        }
    }

    private static func short(_ error: Error) -> String {
        String(String(describing: error).prefix(80))
    }
}
