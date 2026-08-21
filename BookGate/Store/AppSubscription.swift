import Foundation
import SubscriptionKit

/// BookGate's subscription products, in one place.
///
/// The engine lives in **SubscriptionKit** (shared across apps): entitlement from the
/// on-device signed transaction store, the catalogue fetch, purchase, restore, and the
/// paywall's logic. This file is the whole of BookGate's side of it — the product ids,
/// the legal links, and the debug bypass.
///
/// The ids MUST match App Store Connect *and* `BookGate.storekit`: `entitlementProductIDs`
/// is what entitlement is filtered against, so a typo here locks every paying user out.
///
/// The **3-day free trial is an introductory offer configured in App Store Connect**, not
/// app logic. StoreKit reports the trial transaction like any other entitlement, so the
/// trial and the paid period are indistinguishable here — which is exactly right, both
/// unlock the app.
enum AppSubscription {

    static let monthlyID = "com.bookgate.premium.monthly"
    static let yearlyID  = "com.bookgate.premium.yearly"

    static let config = SubscriptionConfig(
        plans: [
            // rank is display order — there is no sorting anywhere in the package.
            .init(id: yearlyID,  rank: 0, isRecommended: true),
            .init(id: monthlyID, rank: 1),
        ],
        termsURL: Legal.termsURL,
        privacyURL: Legal.privacyURL,
        debugOverrides: debugOverrides
    )

    /// Dev bypass (`BOOKGATE_PRO=1`) so the onboarding→home flow can be walked without
    /// buying anything. Constructed inside the app's own `#if DEBUG` as well as the
    /// package's — this is revenue-critical, and one gate isn't worth betting on.
    private static var debugOverrides: DebugOverrides {
        #if DEBUG
        .init(forceEntitledEnvironment: .init(key: "BOOKGATE_PRO", value: "1"))
        #else
        .none
        #endif
    }
}
