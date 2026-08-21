import XCTest
import StoreKit
import SubscriptionKit
@testable import BookGate

/// The guardrail SubscriptionKit's adoption guide calls non-negotiable.
///
/// Entitlement is filtered against `entitlementProductIDs`. A single typo there — or a product id
/// changed in App Store Connect and not here — silently locks out every paying subscriber, and
/// nothing else in the build would notice. Ten lines, asserted against the same `.storekit` file
/// the app ships its scheme with.
final class SubscriptionConfigTests: XCTestCase {

    func testConfigMatchesTheStoreKitFile() throws {
        let ids = try Self.productIDsInStoreKitFile()
        XCTAssertEqual(
            ids, AppSubscription.config.entitlementProductIDs,
            """
            AppSubscription and BookGate.storekit disagree about product ids. \
            Whichever is wrong, fix it before shipping: entitlement is filtered against \
            AppSubscription's set, so an id that only exists on one side entitles nobody.
            """
        )
    }

    /// Both plans must be entitling, or a user could buy something that never unlocks the app.
    func testEveryPlanIsAlsoEntitling() {
        let planIDs = Set(AppSubscription.config.plans.map(\.id))
        XCTAssertTrue(planIDs.isSubset(of: AppSubscription.config.entitlementProductIDs))
    }

    /// The design puts yearly first and badges it; `rank` is the only ordering the package has.
    func testYearlyLeadsAndIsRecommended() {
        XCTAssertEqual(AppSubscription.config.orderedPlanIDs,
                       [AppSubscription.yearlyID, AppSubscription.monthlyID])
        XCTAssertEqual(AppSubscription.config.plans.first(where: \.isRecommended)?.id,
                       AppSubscription.yearlyID)
    }

    /// App Review requires functional Terms and Privacy links on a subscription paywall.
    func testLegalLinksAreHTTPS() {
        for url in [AppSubscription.config.termsURL, AppSubscription.config.privacyURL] {
            XCTAssertEqual(url.scheme, "https", "\(url) must be a working https link")
        }
    }

    // MARK: Fixture

    /// Every product id declared in the app's own `.storekit`, whatever kind it is.
    static func productIDsInStoreKitFile() throws -> Set<String> {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BookGate", withExtension: "storekit"),
                                "BookGate.storekit is missing from the test bundle's resources")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        var ids: Set<String> = []

        for group in json?["subscriptionGroups"] as? [[String: Any]] ?? [] {
            for subscription in group["subscriptions"] as? [[String: Any]] ?? [] {
                if let id = subscription["productID"] as? String { ids.insert(id) }
            }
        }
        for product in (json?["products"] as? [[String: Any]] ?? [])
            + (json?["nonRenewingSubscriptions"] as? [[String: Any]] ?? []) {
            if let id = product["productID"] as? String { ids.insert(id) }
        }
        return ids
    }
}
