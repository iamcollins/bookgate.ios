import Observation
import StoreKit

/// Owns the app's single "BookGate Pro" subscription and the entitlement the
/// paywall gate reads. StoreKit 2 only — no receipt parsing, no server.
///
/// The **3-day free trial is an introductory offer configured in App Store
/// Connect**, not app logic: StoreKit reports the trial transaction inside
/// `Transaction.currentEntitlements` for its duration, so `isSubscribed` is
/// simply "has an active, unrevoked entitlement to one of our products" — the
/// trial and the paid period are indistinguishable here, which is exactly what
/// we want (both unlock the app).
@MainActor @Observable
final class SubscriptionStore {

    /// Product identifiers — must match App Store Connect *and* `BookGate.storekit`.
    static let monthlyID = "app.bookgate.pro.monthly"
    static let yearlyID  = "app.bookgate.pro.yearly"
    static let productIDs = [yearlyID, monthlyID]

    /// Loaded products, sorted most-valuable first (yearly, then monthly).
    private(set) var products: [Product] = []

    /// Where the product fetch stands, so the paywall can distinguish "still
    /// loading" (spinner) from "the fetch failed / came back empty" (error + retry)
    /// instead of spinning forever when offline.
    enum ProductLoadState { case idle, loading, loaded, failed }
    private(set) var productLoadState: ProductLoadState = .idle

    /// Product IDs the user is currently eligible to get the intro (free-trial)
    /// offer on. The paywall advertises "3 days free" *only* for these: StoreKit
    /// grants an intro offer once per subscription group, so a returning subscriber
    /// who already used the trial is NOT eligible and would be charged immediately —
    /// promising them a trial they won't actually get is misleading (and a refund /
    /// complaint risk). Empty until `loadProducts` resolves it.
    private(set) var introEligible: Set<String> = []

    /// Outcome of a purchase attempt — richer than a Bool so the paywall can tell a
    /// silent user-cancel from a real failure (which deserves an alert) or a pending
    /// Ask-to-Buy approval.
    enum PurchaseOutcome { case success, cancelled, pending, failed }

    /// Outcome of a restore attempt, so the UI can say "restored", "nothing found",
    /// or "failed" rather than silently doing nothing.
    enum RestoreOutcome { case restored, nothingFound, failed }

    /// A plan as the paywall renders it — backed by a real StoreKit `Product`,
    /// or (DEBUG only) hardcoded so the onboarding→home flow can be walked
    /// without App Store Connect products or a StoreKit config.
    struct PlanDisplay: Identifiable, Equatable {
        let id: String
        let name: String
        let price: String
        let period: String
        let trial: String?
        /// nil ⇒ a hardcoded DEBUG plan (mock purchase); non-nil ⇒ real product.
        let productID: String?
    }
    /// The gate's source of truth: an active, unrevoked entitlement to Pro.
    private(set) var isSubscribed = false
    /// True once the first entitlement check finishes, so the gate never flashes
    /// the paywall before StoreKit has answered.
    private(set) var hasResolved = false
    /// A purchase / restore is in flight — drives the CTA spinner.
    private(set) var working = false

    /// Called after every entitlement resolution (`refresh`) — launch, foreground,
    /// purchase/restore, or a live `Transaction.updates` tick. `AppServices` wires
    /// this to reconcile alarm scheduling with entitlement.
    var onChange: (() -> Void)?

    private var updatesTask: Task<Void, Never>?

    #if DEBUG
    /// Dev bypass (BOOKGATE_PRO=1): treat the user as always subscribed so the
    /// paywall is skipped and `refresh()` can't revoke it.
    private let debugForcePro = ProcessInfo.processInfo.environment["BOOKGATE_PRO"] == "1"
    #endif

    init() {
        // Listen for renewals, revocations, refunds, Ask-to-Buy approvals, and
        // purchases made on other devices for the app's whole lifetime.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = update {
                    await tx.finish()
                    await self.refresh()
                }
            }
        }
    }

    /// One-shot startup: resolve entitlement first (fast, and sets `hasResolved`
    /// so the paywall can decide), then fetch products for display. Ordering
    /// matters: `Product.products` can stall on device, and gating the UI on it
    /// would leave the paywall stuck on a spinner with no prices.
    func bootstrap() async {
        #if DEBUG
        // Dev bypass: skip the paywall to land on the home surface (same path a
        // real purchase takes). Applied first so a slow/hanging product fetch
        // can't defer it.
        if debugForcePro { isSubscribed = true; hasResolved = true }
        #endif
        await refresh()
        await loadProducts()
    }

    func loadProducts() async {
        productLoadState = .loading
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price > $1.price }
            await refreshIntroEligibility()
            // Empty (network hiccup, or products not yet propagated) is a failure
            // for the UI's purposes — otherwise the paywall spins forever.
            productLoadState = products.isEmpty ? .failed : .loaded
        } catch {
            products = []
            introEligible = []
            productLoadState = .failed
        }
    }

    /// Resolve which loaded products the user can still get the free trial on (see
    /// `introEligible`). Eligibility is per subscription group, surfaced per product
    /// by StoreKit's async `isEligibleForIntroOffer`.
    private func refreshIntroEligibility() async {
        var eligible: Set<String> = []
        for product in products {
            guard let sub = product.subscription, sub.introductoryOffer != nil else { continue }
            if await sub.isEligibleForIntroOffer {
                eligible.insert(product.id)
            }
        }
        introEligible = eligible
    }

    /// What the paywall renders. Maps real products to `PlanDisplay`; in DEBUG,
    /// when no products are available (e.g. a plain Simulator with no StoreKit
    /// config), falls back to hardcoded plans so the flow stays walkable. On
    /// device (TestFlight/App Store) it shows the real App Store Connect products
    /// or nothing — never the mocks.
    var plans: [PlanDisplay] {
        if !products.isEmpty {
            return products.map { p in
                PlanDisplay(id: p.id,
                            name: p.displayName,
                            price: p.displayPrice,
                            period: Self.periodUnitText(for: p),
                            // Only advertise the trial when the user is actually
                            // eligible — otherwise they'd be charged immediately.
                            trial: introEligible.contains(p.id) ? Self.freeTrialText(for: p) : nil,
                            productID: p.id)
            }
        }
        #if DEBUG
        if hasResolved { return Self.mockPlans }
        #endif
        return []
    }

    /// Percentage the yearly plan saves versus 12× monthly, computed from the real product prices —
    /// never hard-coded (the design's "SAVE 58%" is a placeholder). Nil until both prices load.
    var yearlySavingsPercent: Int? {
        guard let monthly = products.first(where: { $0.id == Self.monthlyID })?.price,
              let yearly = products.first(where: { $0.id == Self.yearlyID })?.price else {
            #if DEBUG
            // Mock prices (4.99 / 29.99) so the badge shows while walking the flow.
            if products.isEmpty && hasResolved { return 50 }
            #endif
            return nil
        }
        let full = monthly * 12
        guard full > 0, yearly < full else { return nil }
        let pct = ((full - yearly) / full as NSDecimalNumber).doubleValue * 100
        return pct > 0 ? Int(pct.rounded()) : nil
    }

    #if DEBUG
    /// Hardcoded plans for walking the onboarding flow without App Store Connect
    /// (e.g. a plain Simulator with no StoreKit config). DEBUG-only — a device,
    /// TestFlight, or App Store build shows real products or nothing.
    static let mockPlans: [PlanDisplay] = [
        PlanDisplay(id: yearlyID, name: String(localized: "Yearly"), price: "$29.99",
                    period: String(localized: "year"), trial: String(localized: "3 days free"),
                    productID: nil),
        PlanDisplay(id: monthlyID, name: String(localized: "Monthly"), price: "$4.99",
                    period: String(localized: "month"), trial: String(localized: "3 days free"),
                    productID: nil),
    ]
    #endif

    /// Purchase a plan. Routes to real StoreKit for product-backed plans; a
    /// hardcoded DEBUG plan just flips the entitlement so the gate opens.
    @discardableResult
    func purchase(_ plan: PlanDisplay) async -> PurchaseOutcome {
        if let pid = plan.productID, let product = products.first(where: { $0.id == pid }) {
            return await purchase(product)
        }
        #if DEBUG
        working = true
        isSubscribed = true
        working = false
        return .success
        #else
        return .failed
        #endif
    }

    /// Recompute `isSubscribed` from the current entitlements. An active intro
    /// trial is present here just like a paid period, so it counts as subscribed.
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productType == .autoRenewable,
               Self.productIDs.contains(tx.productID),
               tx.revocationDate == nil {
                active = true
            }
        }
        #if DEBUG
        isSubscribed = active || debugForcePro
        #else
        isSubscribed = active
        #endif
        hasResolved = true
        onChange?()
    }

    /// Purchase a product. `.success` once entitlement is granted (incl. the intro
    /// trial); `.cancelled` if the user backed out (silent); `.pending` for
    /// Ask-to-Buy (unlocks later via `Transaction.updates`); `.failed` on error or
    /// an unverified transaction.
    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        working = true
        defer { working = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    // A verified purchase transaction is itself the proof of
                    // entitlement — unlock from it directly. Previously we re-derived
                    // success via refresh() (Transaction.currentEntitlements), which
                    // RACES the purchase: currentEntitlements often hasn't propagated
                    // the new transaction yet, so the FIRST tap spuriously returned
                    // .failed ("Something went wrong") even though the buy succeeded;
                    // the second tap then saw the settled entitlement and "worked".
                    guard tx.revocationDate == nil else { return .failed }  // refunded/revoked
                    isSubscribed = true
                    hasResolved = true
                    onChange?()
                    return .success
                }
                return .failed        // unverified — don't unlock
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Restore prior purchases (App Store account sync), then re-resolve. Reports
    /// whether anything was restored so the UI can give feedback either way.
    @discardableResult
    func restore() async -> RestoreOutcome {
        working = true
        defer { working = false }
        do {
            try await AppStore.sync()
        } catch {
            // Sync failed or the user dismissed the sign-in — still re-resolve, in
            // case they're already entitled, but otherwise report a failure.
            await refresh()
            return isSubscribed ? .restored : .failed
        }
        await refresh()
        return isSubscribed ? .restored : .nothingFound
    }

    // MARK: Display helpers

    /// Localized free-trial phrase for a product's intro offer, e.g. "3 days
    /// free", or nil if the product has no free-trial introductory offer.
    static func freeTrialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let unit = offer.period.unit
        let count = offer.period.value
        let formatted = Self.periodDescription(unit: unit, count: count)
        return String(localized: "\(formatted) free",
                      comment: "Free-trial length, e.g. '3 days free'")
    }

    /// Localized billing period for a product, e.g. "month" / "year".
    static func periodUnitText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        return Self.periodDescription(unit: period.unit, count: period.value)
    }

    private static func periodDescription(unit: Product.SubscriptionPeriod.Unit, count: Int) -> String {
        switch unit {
        case .day:   return String(localized: "\(count) day")
        case .week:  return String(localized: "\(count) week")
        case .month: return String(localized: "\(count) month")
        case .year:  return String(localized: "\(count) year")
        @unknown default: return ""
        }
    }
}
