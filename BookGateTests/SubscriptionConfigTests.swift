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


    /// The DEBUG preview prices exist so the paywall can be *reviewed* at the widths it will
    /// really have. When they drift from the `.storekit` fixture, every layout judgement and
    /// every screenshot is made against a price nobody is charged — and the savings badge is
    /// computed from them, so a wrong monthly price silently changes it (50% at $4.99,
    /// 58% at $5.99).
    ///
    /// This caught exactly that drift: the fixture said $5.99 while the preview said $4.99.
    func testPreviewPricesMatchTheStoreKitFile() throws {
        let fixture = try Self.subscriptionsInStoreKitFile()
        for plan in AppSubscription.previewPlansForTesting {
            let row = try XCTUnwrap(fixture[plan.id], "no \(plan.id) in BookGate.storekit")
            XCTAssertEqual(
                plan.displayPrice, "$" + row.price,
                "\(plan.id): preview says \(plan.displayPrice), BookGate.storekit says $\(row.price). "
                + "Whichever is wrong, the paywall is being reviewed against a price it never charges."
            )
        }
    }

    /// The preview's savings badge is **stated**, while the shipping one is **computed** from
    /// real prices — so the two can drift apart without anything failing. At $5.99 monthly the
    /// real badge is 58% while the stated one still read 50%, and nothing noticed. This pins
    /// the stated number to the prices it claims to describe.
    func testStatedPreviewSavingsMatchesWhatThosePricesActuallyWorkOutTo() throws {
        let plans = AppSubscription.previewPlansForTesting
        let yearly = try XCTUnwrap(plans.first { $0.id == AppSubscription.yearlyID })
        let monthly = try XCTUnwrap(plans.first { $0.id == AppSubscription.monthlyID })

        let stated = try XCTUnwrap(yearly.savingsPercentVsMonthly,
                                   "the yearly preview card states a saving")
        let computed = try XCTUnwrap(
            Savings.percent(yearlyPrice: try Self.price(yearly.displayPrice),
                            monthlyPrice: try Self.price(monthly.displayPrice)),
            "\(yearly.displayPrice) against \(monthly.displayPrice) works out to no saving at all"
        )
        XCTAssertEqual(
            stated, computed,
            "the preview card says SAVE \(stated)% while \(yearly.displayPrice) against "
            + "\(monthly.displayPrice) is \(computed)% — the shipping badge computes it, so the "
            + "screen being reviewed is not the screen that ships."
        )
    }

    /// Both plans must carry the free trial the paywall advertises, for the same length.
    /// Promising a trial a product does not offer is a misleading subscription presentation.
    func testEveryPlanCarriesTheTrialThePaywallAdvertises() throws {
        let fixture = try Self.subscriptionsInStoreKitFile()
        for id in AppSubscription.config.entitlementProductIDs.sorted() {
            let row = try XCTUnwrap(fixture[id], "no \(id) in BookGate.storekit")
            XCTAssertEqual(row.offerMode, "free", "\(id): the paywall advertises a *free* trial")
            XCTAssertEqual(row.offerPeriod, "P3D", "\(id): the paywall says three days")
        }
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

    /// Price and introductory offer per product, straight out of the fixture.
    struct FixtureRow { let price: String; let offerMode: String?; let offerPeriod: String? }

    /// "$29.99" → `29.99`, so a display string can be compared against real arithmetic.
    static func price(_ display: String) throws -> Decimal {
        let digits = display.filter { $0.isNumber || $0 == "." }
        return try XCTUnwrap(Decimal(string: digits), "no price to read in \(display)")
    }

    static func subscriptionsInStoreKitFile() throws -> [String: FixtureRow] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BookGate", withExtension: "storekit"),
                                "BookGate.storekit is missing from the test bundle's resources")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        var rows: [String: FixtureRow] = [:]
        for group in json?["subscriptionGroups"] as? [[String: Any]] ?? [] {
            for subscription in group["subscriptions"] as? [[String: Any]] ?? [] {
                guard let id = subscription["productID"] as? String,
                      let price = subscription["displayPrice"] as? String else { continue }
                let offer = subscription["introductoryOffer"] as? [String: Any]
                rows[id] = FixtureRow(price: price,
                                      offerMode: offer?["paymentMode"] as? String,
                                      offerPeriod: offer?["subscriptionPeriod"] as? String)
            }
        }
        return rows
    }

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
