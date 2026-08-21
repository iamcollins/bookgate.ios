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
    /// buying anything, plus the prices the paywall shows when StoreKit has nothing to say.
    /// Constructed inside the app's own `#if DEBUG` as well as the package's — this is
    /// revenue-critical, and one gate isn't worth betting on.
    private static var debugOverrides: DebugOverrides {
        #if DEBUG
        .init(forceEntitledEnvironment: .init(key: "BOOKGATE_PRO", value: "1"),
              previewPlans: previewPlans)
        #else
        .none
        #endif
    }

    #if DEBUG
    /// What the paywall renders on a Simulator, which cannot reach real products: it has no
    /// Sandbox Apple Account setting, and a `.storekit` configuration is attached by Xcode's Run
    /// action, which `simctl` and `xcodebuild` never perform. Without these the paywall is two
    /// empty placeholder cards on every machine, which makes the screen impossible to review.
    ///
    /// **These are placeholders, not the truth.** The moment StoreKit resolves anything — a device,
    /// TestFlight, sandbox — the real App Store Connect prices win, and this is never compiled into
    /// a Release build. Keep them close to the real ones so the layout is reviewed at the right
    /// widths; the savings badge here is stated, while the shipping one is computed.
    private static let previewPlans: [PreviewPlan] = [
        .init(id: yearlyID, displayName: "Yearly", displayPrice: "$29.99",
              pricePerMonth: "$2.50", period: .init(unit: .year, value: 1),
              introOffer: .freeTrial(days: 3), isRecommended: true,
              savingsPercentVsMonthly: 58),
        .init(id: monthlyID, displayName: "Monthly", displayPrice: "$5.99",
              period: .init(unit: .month, value: 1),
              introOffer: .freeTrial(days: 3)),
    ]
    #endif
}
