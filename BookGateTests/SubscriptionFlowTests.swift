import XCTest
import StoreKit
import StoreKitTest
import SubscriptionKit
@testable import BookGate

/// The real StoreKit coverage. SubscriptionKit deliberately does **not** host these — `SKTestSession`
/// does not work from a package's own test bundle (see the package's FINDINGS.md), so its plan is
/// for the first adopting app to prove the engine against a real app context. That is this file.
///
/// Every test drives BookGate's actual `AppSubscription.config`, so a product id or an intro offer
/// that is wrong here is wrong in the shipping app.
///
/// Run serially — `SKTestSession` mutates process-global state:
/// `xcodebuild test -parallel-testing-enabled NO`.
@MainActor
final class SubscriptionFlowTests: XCTestCase {

    private var session: SKTestSession!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BookGate", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true          // nothing may block a headless run
        session.resetToDefaultState()
        session.clearTransactions()
        session.storefront = "USA"
        // A hang is worse than a failure on CI: fail the case instead of stalling the run.
        // Needs `-test-timeouts-enabled YES` (see Scripts/test.sh).
        executionTimeAllowance = 60
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    /// An activated store, or a skipped test.
    ///
    /// **Every test here goes through this, and that is load-bearing.** When `SKTestSession` does
    /// not take effect — which is the case on this machine, and was also true inside
    /// SubscriptionKit's own test bundle — StoreKit silently falls through to the *real* App Store.
    /// BookGate has no products there yet, so the catalogue comes back empty and, worse,
    /// `restore()` → `AppStore.sync()` raises a real "Sign in to Apple Account" sheet that blocks
    /// the run until the 600-second timeout. Skipping on an unresolved catalogue keeps that
    /// failure honest and fast: the suite says exactly what is missing instead of hanging.
    ///
    /// These tests run for real once the products exist in App Store Connect — on device, or in a
    /// simulator signed into a sandbox account.
    private func activatedStoreOrSkip() async throws -> SubscriptionStore {
        let store = SubscriptionStore(config: AppSubscription.config)
        await store.activate()
        guard case .loaded = store.productLoadState, !store.products.isEmpty else {
            throw XCTSkip("""
                StoreKit resolved no products, so this environment cannot exercise a purchase. \
                SKTestSession did not take effect and there are no App Store Connect products for \
                \(AppSubscription.config.entitlementProductIDs.sorted().joined(separator: ", ")). \
                Run this suite on a device or a sandbox-signed simulator once the products exist.
                """)
        }
        return store
    }

    // MARK: The gate

    func testFreshUserIsNotEntitledAndSeesBothPlans() async throws {
        let store = try await activatedStoreOrSkip()

        XCTAssertEqual(store.entitlement, .notEntitled)
        XCTAssertEqual(store.productLoadState, .loaded)

        let model = PaywallModel(store: store)
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.plans.map(\.id), [AppSubscription.yearlyID, AppSubscription.monthlyID])
        // Yearly is preselected because it is the recommended plan.
        XCTAssertEqual(model.selectedPlanID, AppSubscription.yearlyID)
    }

    func testPurchaseOpensTheGateOnTheFirstAttempt() async throws {
        let store = try await activatedStoreOrSkip()
        let product = try XCTUnwrap(store.product(AppSubscription.yearlyID))

        let outcome = try await store.purchase(product)

        // The first tap must unlock. Deriving entitlement from currentEntitlements instead of the
        // purchase's own transaction used to race, and reported failure on a successful buy.
        XCTAssertEqual(outcome, .success)
        XCTAssertTrue(store.isEntitled)
        XCTAssertTrue(store.entitledProductIDs.contains(AppSubscription.yearlyID))
    }

    func testExpiredSubscriptionClosesTheGate() async throws {
        let store = try await activatedStoreOrSkip()
        let product = try XCTUnwrap(store.product(AppSubscription.monthlyID))
        _ = try await store.purchase(product)
        XCTAssertTrue(store.isEntitled)

        try session.expireSubscription(productIdentifier: AppSubscription.monthlyID)
        let state = await store.refreshEntitlement()

        XCTAssertEqual(state, .notEntitled)
        XCTAssertFalse(store.isEntitled)
    }

    func testRefundClosesTheGate() async throws {
        let store = try await activatedStoreOrSkip()
        let product = try XCTUnwrap(store.product(AppSubscription.yearlyID))
        _ = try await store.purchase(product)

        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        let state = await store.refreshEntitlement()

        XCTAssertEqual(state, .notEntitled)
    }

    // MARK: Restore

    func testRestoreWithNothingBoughtIsAnAnswerNotAnError() async throws {
        let store = try await activatedStoreOrSkip()

        let outcome = await store.restore()

        // "Nothing to restore" is a normal reply. Reporting it as a failure sends a user who never
        // subscribed to support.
        XCTAssertEqual(outcome, .nothingFound)
    }

    func testRestoreFindsAnExistingSubscription() async throws {
        let store = try await activatedStoreOrSkip()
        let product = try XCTUnwrap(store.product(AppSubscription.yearlyID))
        _ = try await store.purchase(product)

        let outcome = await store.restore()

        XCTAssertEqual(outcome, .restored)
    }

    // MARK: The trial

    func testTrialIsOfferedToANewUserAndWithdrawnAfterItIsUsed() async throws {
        let store = try await activatedStoreOrSkip()
        let model = PaywallModel(store: store)

        let yearly = try XCTUnwrap(model.plans.first { $0.id == AppSubscription.yearlyID })
        XCTAssertNotNil(yearly.introOffer, "a first-time user must be offered the free trial")
        XCTAssertEqual(yearly.introOffer?.paymentMode, .freeTrial)

        _ = try await store.purchase(try XCTUnwrap(store.product(AppSubscription.yearlyID)))

        // A second store, as if the app relaunched: the offer is spent, so the paywall must stop
        // promising it. Advertising a trial to someone who would be charged is a misleading
        // subscription presentation.
        let later = try await activatedStoreOrSkip()
        let laterModel = PaywallModel(store: later)
        for plan in laterModel.plans {
            XCTAssertNil(plan.introOffer, "\(plan.id) still advertises a trial the user cannot get")
        }
    }

    // MARK: Prices

    func testYearlySavingsAreComputedFromRealPrices() async throws {
        let store = try await activatedStoreOrSkip()
        let model = PaywallModel(store: store)

        let yearly = try XCTUnwrap(model.plans.first { $0.id == AppSubscription.yearlyID })
        let monthly = try XCTUnwrap(model.plans.first { $0.id == AppSubscription.monthlyID })

        XCTAssertNil(monthly.savingsPercentVsMonthly, "a monthly plan cannot save against itself")
        XCTAssertNotNil(yearly.pricePerMonth, "the design quotes yearly per month")
        let percent = try XCTUnwrap(yearly.savingsPercentVsMonthly)
        XCTAssertTrue((1...99).contains(percent), "implausible savings badge: \(percent)%")
    }

    func testPricesFollowTheStorefront() async throws {
        session.storefront = "JPN"
        let store = try await activatedStoreOrSkip()

        let yearly = try XCTUnwrap(store.product(AppSubscription.yearlyID))

        // A hardcoded fallback price would quote dollars here — which is why there isn't one.
        XCTAssertTrue(yearly.displayPrice.contains("¥"),
                      "expected yen on the Japanese storefront, got \(yearly.displayPrice)")
    }

    // MARK: Offline

    func testALiveSubscriberGetsInEvenWhenTheCatalogueFails() async throws {
        let store = try await activatedStoreOrSkip()
        _ = try await store.purchase(try XCTUnwrap(store.product(AppSubscription.yearlyID)))

        try await session.setSimulatedError(.generic(.unknown), forAPI: .loadProducts)
        let offline = SubscriptionStore(config: AppSubscription.config)
        await offline.activate()      // deliberately NOT the skipping helper: a failed catalogue is the point

        // Entitlement comes from the on-device transaction store, so it must not be gated behind
        // the network catalogue fetch. An offline launch still lets a paying subscriber straight in.
        XCTAssertTrue(offline.isEntitled)
        if case .failed = offline.productLoadState {} else {
            XCTFail("expected the catalogue fetch to fail, got \(offline.productLoadState)")
        }
    }
}
