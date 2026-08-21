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

    /// Whether `SKTestSession` is actually intercepting StoreKit in this process. Probed once
    /// per run and cached — the answer cannot change mid-run.
    ///
    /// **Why a skip exists at all.** When the session is not in control, StoreKit falls through
    /// to the real App Store, and a `restore()` there reaches `AppStore.sync()`, which raises a
    /// "Sign in to Apple Account" sheet and stalls the run until its timeout. An honest skip
    /// beats a red suite that proves nothing.
    ///
    /// **Why this probe and not the storefront.** The previous version set
    /// `session.storefront = "JPN"` and checked whether prices came back in yen. That is a proxy
    /// with at least two false-negative modes — `Product.products(for:)` caches per process, and
    /// a storefront change does not propagate synchronously — so it could report "not
    /// intercepting" about a session that was working perfectly well. It is replaced with the
    /// direct question: buy something locally and see whether the transaction lands. If the
    /// session is inert this throws immediately, with no dialog and no hang.
    private func skipUnlessStoreKitIsLocal() async throws {
        if Self.storeKitIsLocal == nil {
            Self.storeKitIsLocal = await Self.canTransactLocally(in: session)
        }
        guard Self.storeKitIsLocal == true else {
            throw XCTSkip("""
                A local StoreKit purchase did not land, so `SKTestSession` is not intercepting \
                StoreKit in this process and these cases would run against the real App Store — \
                where a restore raises a sign-in sheet and stalls the run. \
                Diagnostic from the probe: \(Self.probeDiagnostic ?? "none"). \
                Run from Xcode with BookGate.storekit on the scheme, or on a device signed into \
                a sandbox account.
                """)
        }
    }

    /// The direct signal: buy a product through the test session and check a transaction exists.
    /// Cleans up after itself so the case that follows starts from nothing.
    private static func canTransactLocally(in session: SKTestSession) async -> Bool {
        // Both halves of the picture: what the catalogue says, and whether a local purchase
        // lands. A live-but-empty session and an inert one look identical from either alone.
        let resolved = (try? await Product.products(for: Array(AppSubscription.config.entitlementProductIDs))) ?? []
        let catalogue = "products resolved: \(resolved.count) [\(resolved.map { "\($0.id)=\($0.displayPrice)" }.joined(separator: ", "))]"
        do {
            try await session.buyProduct(identifier: AppSubscription.monthlyID)
        } catch {
            probeDiagnostic = "buyProduct threw: \(error); \(catalogue)"
            return false
        }
        let landed = session.allTransactions().contains { $0.productIdentifier == AppSubscription.monthlyID }
        session.clearTransactions()
        if !landed { probeDiagnostic = "buyProduct succeeded but no transaction was recorded" }
        return landed
    }

    /// Probed once for the whole suite — the answer cannot change mid-run.
    private static var storeKitIsLocal: Bool?
    /// Whatever the probe learned, surfaced in the skip message so a skip is never a dead end.
    private static var probeDiagnostic: String?

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
        try await skipUnlessStoreKitIsLocal()
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
        // The skip probe restores whatever storefront it found, so set Japan after it has run.
        try await skipUnlessStoreKitIsLocal()
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
