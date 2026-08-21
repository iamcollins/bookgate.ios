import SwiftUI
import StoreKit
import SubscriptionKit

/// The paywall (screen 8f). No free tier: a 3-day trial, then subscription. The **timeline is
/// stated before the price** (today / day 2 / day 3), yearly is preselected, the savings badge is
/// **computed** from real prices, and there is one CTA. Used as onboarding's last step and as the
/// lapsed hard wall (laid over Today, no dismiss; never shown while an alarm rings).
///
/// All logic lives in SubscriptionKit's `PaywallModel` — what state the screen is in, which plans
/// exist and in what order, which is selected, whether a trial may be mentioned at all. **Every
/// word on this screen is BookGate's**, formatted here from the structured facts the model vends
/// (`Product.SubscriptionPeriod`, `Product.SubscriptionOffer`, a savings percentage), because a
/// `String(localized:)` inside a package silently returns its key in every non-English locale.
///
/// NOTE: the trial-timeline wording is **regulated** — it needs legal/store sign-off before
/// shipping (flagged in the handoff's Open items). Prices are now always the real storefront ones:
/// there is no hardcoded fallback, by design.
struct PaywallView: View {
    /// Called when an entitlement is active (purchase or restore).
    var onSubscribed: () -> Void

    /// A way back out, supplied **only** by onboarding. The hard wall passes nothing, so the
    /// close button cannot appear there — a lapsed reader is not offered a way to keep using
    /// a subscription they no longer have, and that is enforced by what the caller hands
    /// over rather than by a flag this view could get wrong.
    var onClose: (() -> Void)? = nil

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var model: PaywallModel?
    @State private var message: String?
    @State private var showManage = false

    /// True while a retry pass owns the screen, so the reader sees "trying" rather than a
    /// verdict the screen is still working on — and so two passes can never overlap.
    @State private var isRetrying = false
    /// The automatic ladder runs once per appearance of this screen, however it is kicked.
    @State private var hasAutoRetried = false

    /// The automatic ladder: two attempts, one second then two. A first-time reader cannot get
    /// past this screen without prices, so it tries on their behalf before asking them to. Each
    /// fetch can itself run the full 20-second timeout, so a third pushed the total wait past a
    /// minute — measured on a forced failure, not guessed.
    private static let autoRetryDelays: [Duration] = [.seconds(1), .seconds(2)]

    /// Why this screen is being shown, when the store has established it. `nil` while
    /// entitlement is still resolving, and `.neverSubscribed` for the first-run case.
    private var lapse: EntitlementLapse? { services.subscription.lapse }

    /// Whether a returning reader has actually ended, rather than never started.
    private var hasLapsed: Bool {
        guard let lapse else { return false }
        return lapse.reason != .neverSubscribed
    }

    /// The close button needs both: a caller that offered one, and a reader who has never
    /// subscribed. Someone who reinstalled after lapsing still walks onboarding, and they
    /// are not a new user — they meet the same offer as they would at the wall.
    private var showsClose: Bool { onClose != nil && !hasLapsed }

    /// Whether a *free trial* is genuinely on the table for the selected plan.
    ///
    /// The three-day timeline used to be static copy shown to everyone. Someone who has
    /// already used their trial is not eligible for another, so they were being told
    /// "three days on us" above a button that said "Subscribe" — a misleading subscription
    /// presentation, and the sort of thing App Review rejects for.
    private var trialIsOnOffer: Bool {
        // Someone who has had a subscription before has already used the introductory
        // offer — Apple allows one per subscription group per account. StoreKit reports
        // that itself, but only once eligibility resolves, so this states it outright:
        // a returning reader is never promised a free trial.
        guard !hasLapsed else { return false }
        return model?.selectedPlan?.introOffer?.paymentMode == .freeTrial
    }

    /// The plan that ended, in words, for the lapse copy.
    private var lapsedPlanName: String? {
        switch lapse?.productID {
        case AppSubscription.yearlyID:  return String(localized: "yearly plan")
        case AppSubscription.monthlyID: return String(localized: "monthly plan")
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.12))
            // This screen must not scroll on a phone it fits on — and must not clip on one it
            // doesn't. So the page is given a minimum height of exactly the viewport: its spacers
            // expand to fill a tall screen (nothing to scroll, and `basedOnSize` removes even the
            // rubber-band bounce), while a short screen lets the content grow past the viewport and
            // scroll honestly. `ViewThatFits` was tried first and measured a hair short — a custom
            // font's real line heights are not its reported ideal ones — which clipped the footer
            // off the bottom of an iPhone SE.
            GeometryReader { geo in
                ScrollView {
                    page(tight: geo.size.height < 700)
                        .frame(minHeight: geo.size.height, alignment: .top)
                        .padding(.horizontal, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if showsClose { closeButton }
        }
        .task {
            if model == nil { model = PaywallModel(store: services.subscription) }
            // Already entitled when this appears — a restore on a previous launch, or a
            // subscription bought on another device. `onChange` never fires for a state that was
            // already true, which left onboarding's last step with no way forward.
            if services.subscription.entitlement == .entitled { onSubscribed() }
            await model?.load()
            await autoRetryIfFailing()
        }
        .onChange(of: services.subscription.entitlement) { _, now in
            if now == .entitled { onSubscribed() }
        }
        // The other half of the kick — see `autoRetryIfFailing()`. On the hard wall the
        // catalogue fetch is usually still in flight when this screen mounts, so the ladder
        // has to be able to start when the failure lands rather than only at mount.
        .onChange(of: model?.state) { _, _ in
            Task { await autoRetryIfFailing() }
        }
    }

    /// Sits where onboarding's back control sits on its other steps, so "leave this step"
    /// stays in one place across the flow.
    private var closeButton: some View {
        Button { onClose?() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.ink(.secondary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 4)
    }

    /// The page, laid out once. `tight` only changes the breathing room, never the content — a
    /// small screen shows the same words, closer together.
    private func page(tight: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: tight ? 8 : 16)
            Bookmark(width: 38, height: 52)
            Spacer().frame(height: tight ? 14 : 20)
            Text(headline)
                .font(BGFont.serif(tight ? 28 : 31, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 10)
            Text(subhead)
                .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Only two gaps flex. The offer — timeline then prices — has to read as one block, so
            // the space a tall phone has spare goes above it and below it, never through it.
            Spacer(minLength: tight ? 16 : 22)
            benefits
            // The highlights are prose and the plans are a control — they need a clear
            // break between them, not the rhythm of one list running into the next.
            // Wider than it looks it needs: the savings badge sits *above* the first card's
            // edge, so it eats into whatever gap is set here.
            Spacer().frame(height: tight ? 30 : 46)
            plans
            Spacer(minLength: tight ? 16 : 22)
            cta

            if let message {
                Spacer().frame(height: 10)
                Text(message).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: tight ? 10 : 14)
            footer
            Spacer().frame(height: tight ? 4 : 10)
        }
    }

    private var headline: String {
        guard let lapse else { return String(localized: "Make reading a daily reality.") }
        return LapseCopy.title(lapse)
    }

    private var subhead: String {
        guard let lapse else {
            return String(localized: "Your book, your time, your shield — three days on us.")
        }
        return LapseCopy.detail(lapse, planName: lapsedPlanName)
    }

    // MARK: What you get (constant across every variant)

    /// The middle of this screen never changes. Whether someone is new, lapsed, refunded
    /// or has a failed card, the product on offer is identical — so the only things that
    /// move are the headline, the line under it, the CTA and the note beneath it.
    ///
    /// This replaced a day-by-day trial timeline (today / day 2 / day 3). That described
    /// the *billing schedule*, which is only meaningful to someone being offered a trial,
    /// and said nothing about what BookGate actually does. It also had to be hidden for
    /// every returning reader, which is what made the middle variant-specific in the first
    /// place.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefit("alarm.fill",
                    "A reading alarm you can't wave away",
                    "It keeps going until you show your book to the camera.")
            benefit("hourglass",
                    "The apps that usually win, held back",
                    "Your picks stay locked until the session is done.")
            benefit("waveform",
                    "One thing you'll remember, in your own voice",
                    "Record a takeaway after a session. It's kept with the book.")
            benefit("chart.bar.fill",
                    "Your streak, night after night",
                    "Every night you read is marked — with one rest day a week.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.brassValue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BGFont.ui(14.5, .semibold)).foregroundStyle(palette.ink(.strong))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Plans

    /// Prices are never shown before StoreKit resolves them — a placeholder card holds the layout
    /// instead. A hardcoded fallback would quote dollars to a reader in another storefront.
    @ViewBuilder
    private var plans: some View {
        switch model?.state ?? .idle {
        case .idle, .loading:
            VStack(spacing: 12) { placeholderCard; placeholderCard }
        case .failed:
            unavailableNotice
        case .ready:
            VStack(spacing: 12) {
                ForEach(model?.plans ?? []) { plan in planCard(plan) }
            }
        }
    }

    private func planCard(_ plan: PaywallModel.PlanDisplay) -> some View {
        let isOn = plan.id == model?.selectedPlanID
        return Button { model?.selectedPlanID = plan.id } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName).font(BGFont.ui(16, .semibold)).foregroundStyle(palette.ink(.hero))
                    Text(billingLine(plan))
                        .font(BGFont.ui(13, .semibold))
                        .foregroundStyle(billingLineColor(plan))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(unitPrice(plan)).font(BGFont.serif(26, .light)).foregroundStyle(palette.brassValue)
                    if let caption = unitCaption(plan) {
                        Text(caption).font(BGFont.ui(10.5)).foregroundStyle(palette.ink(.secondary))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.glassCard)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isOn ? palette.brassLabel : palette.glassBorder, lineWidth: isOn ? 1.5 : 1))
            }
            // The badge sits on the card's edge, as in the design — computed from the real
            // prices, never hardcoded.
            .overlay(alignment: .topLeading) {
                if let pct = plan.savingsPercentVsMonthly {
                    savingsBadge(pct).offset(x: 16, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholderCard: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.glassCard)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.glassBorder, lineWidth: 1))
            .frame(height: 78)
    }

    /// Two states, never both at once.
    ///
    /// While a fetch is genuinely in flight the reader sees only that. The error appears only
    /// once the attempts are spent. Showing an error *and* a spinner together — which this
    /// screen briefly did — reads as broken: it announces a verdict it is still working on.
    ///
    /// The paywall usually opens with `productLoadState` already `.failed`, because launch's
    /// own `activate()` has been and failed before this view ever mounts. So the fetching
    /// state has to be driven by our retry, not by the store's state.
    private var unavailableNotice: some View {
        VStack(spacing: 10) {
            if isRetrying {
                ProgressView().tint(palette.brassValue)
                Text("Fetching plans…")
                    .font(BGFont.ui(14, .medium)).foregroundStyle(palette.ink(.strong))
            } else {
                Text("Unable to fetch the available plans from App Store. Please try again shortly.")
                    .font(BGFont.ui(14, .medium)).foregroundStyle(palette.ink(.strong))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try now") { retryNow() }
                    .font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                    .frame(height: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glass(.card, cornerRadius: 22)
    }

    // MARK: Retrying

    /// Retry on the reader's behalf, with a widening gap, before handing them the problem.
    ///
    /// Kicked from **both** `.task` and the state becoming `.failed`, because which of those
    /// comes first is a matter of scheduling. On the hard wall the second one usually wins:
    /// `activate()` resolves entitlement, the wall appears, and the price fetch is still in
    /// flight — so a ladder that only looked at mount saw `.loading`, exited, and never ran
    /// at all. `hasAutoRetried` is what keeps the two kicks to one ladder.
    private func autoRetryIfFailing() async {
        guard !hasAutoRetried, case .failed = model?.state else { return }
        hasAutoRetried = true
        await retry(after: Self.autoRetryDelays)
    }

    /// The manual button: one fetch, immediately. The reader is in control now, so the screen
    /// does not put them back through the patient ladder — that exists to spare someone who
    /// does not know to tap, and re-running it here is what turned a single tap into three
    /// fetches and the best part of a minute of spinner.
    private func retryNow() {
        Task { await retry(after: [.zero]) }
    }

    /// One retry pass: a fetch per delay, stopping the moment the catalogue resolves. A second
    /// pass while one is already running is ignored.
    private func retry(after delays: [Duration]) async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        for delay in delays {
            guard case .failed = model?.state else { return }
            if delay > .zero { try? await Task.sleep(for: delay) }
            await model?.retry()
        }
    }

    private func savingsBadge(_ percent: Int) -> some View {
        Text("SAVE \(percent)%").font(BGFont.ui(9.5, .bold)).tracking(0.8)
            .foregroundStyle(palette.actionText)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(palette.brassObject))
    }

    // MARK: CTA + footer

    @ViewBuilder private var cta: some View {
        if let lapse, LapseCopy.needsPaymentFix(lapse) {
            // A failed payment is Apple's to fix, not ours: the card lives in the Apple
            // Account and only the App Store can change it. So this hands straight over
            // rather than building a payment flow we have no business owning — and it says
            // "Manage subscription", which is what the sheet actually is, instead of
            // promising an inline card edit that happens one screen further in.
            Button("Manage subscription") { showManage = true }
                .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                .manageSubscriptionsSheet(isPresented: $showManage)
        } else {
            Button { purchase() } label: {
                if model?.isBusy == true { ProgressView().tint(palette.actionText) }
                else { Text(ctaLabel) }
            }
            .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
            .disabled(!(model?.canPurchase ?? false))
        }
    }

    private var ctaLabel: String {
        guard trialIsOnOffer,
              let span = model?.selectedPlan.flatMap(freeTrialSpan)
        else { return hasLapsed ? String(localized: "Start reading again")
                                : String(localized: "Subscribe") }
        return String(localized: "Start my \(span)", comment: "CTA, e.g. 'Start my 3 free days'")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(renewalNote).font(BGFont.ui(11, .regular)).foregroundStyle(palette.ink(.caption))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Button("Restore") { restore() }.font(BGFont.ui(12, .medium)).foregroundStyle(palette.brassValue)
                Link("Terms", destination: model?.termsURL ?? Legal.termsURL)
                    .font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
                Link("Privacy", destination: model?.privacyURL ?? Legal.privacyURL)
                    .font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
            }
        }
        .padding(.top, 6)
    }

    /// The disclosure under the CTA. Auto-renewal has to be stated plainly next to the
    /// button that starts it — "cancel any time" alone does not say the thing that renews.
    private var renewalNote: String {
        guard let plan = model?.selectedPlan, let period = periodNoun(plan.period) else { return "" }
        if trialIsOnOffer, let span = trialLength(plan) {
            return String(localized: "Free for \(span), then \(plan.displayPrice) a \(period). Auto-renews until cancelled. Cancel any time in Settings.")
        }
        return String(localized: "\(plan.displayPrice) a \(period). Auto-renews until cancelled. Cancel any time in Settings.")
    }

    // MARK: Copy built from the model's facts
    //
    // Every string below is BookGate's, formatted from `Product.SubscriptionPeriod` /
    // `Product.SubscriptionOffer`. Nothing here may move into the package: a localized string
    // resolved against a package bundle silently returns its key.

    /// The line under the plan name. On a yearly plan it is the per-month equivalent — the
    /// one fact that makes the two cards comparable — and it is set in brass, because that
    /// comparison is the reason to choose it. On a monthly plan there is nothing to convert,
    /// so it just states the billing.
    private func billingLine(_ plan: PaywallModel.PlanDisplay) -> String {
        if let perMonth = plan.pricePerMonth {
            return String(localized: "\(perMonth) a month")
        }
        guard let period = periodNoun(plan.period) else { return plan.displayPrice }
        return String(localized: "Billed every \(period)")
    }

    /// Brass only for the per-month comparison, so the accent means one thing.
    private func billingLineColor(_ plan: PaywallModel.PlanDisplay) -> Color {
        plan.pricePerMonth != nil ? palette.brassValue : palette.ink(.secondary)
    }

    /// The big figure is **the price of the plan you are buying** — the yearly card shows
    /// the yearly price. It used to show the per-month equivalent, so the largest number on
    /// a yearly card was a figure that is never actually charged.
    private func unitPrice(_ plan: PaywallModel.PlanDisplay) -> String {
        plan.displayPrice
    }

    private func unitCaption(_ plan: PaywallModel.PlanDisplay) -> String? {
        guard let period = periodNoun(plan.period) else { return nil }
        return String(localized: "per \(period)")
    }

    /// The bare length — "3 days" — for prose that supplies its own word for free. The CTA
    /// wants "3 free days"; a sentence starting "Free for…" does not, or it reads "3 free
    /// days free".
    private func trialLength(_ plan: PaywallModel.PlanDisplay) -> String? {
        guard let offer = plan.introOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        switch offer.period.unit {
        case .day:   return String(localized: "\(n) days")
        case .week:  return String(localized: "\(n) weeks")
        case .month: return String(localized: "\(n) months")
        case .year:  return String(localized: "\(n) years")
        @unknown default: return nil
        }
    }

    /// "3 days free"-style span for the CTA, or nil when the user is not eligible for a *free*
    /// intro offer. `introOffer` is already nil for an ineligible user — promising a trial that
    /// would charge immediately is a misleading subscription presentation.
    private func freeTrialSpan(_ plan: PaywallModel.PlanDisplay) -> String? {
        guard let offer = plan.introOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        switch offer.period.unit {
        case .day:   return String(localized: "\(n) free days")
        case .week:  return String(localized: "\(n) free weeks")
        case .month: return String(localized: "\(n) free months")
        case .year:  return String(localized: "\(n) free years")
        @unknown default: return nil
        }
    }

    /// "month" / "year", for "a year" and "per month" phrasing. Nil for a non-renewing product.
    private func periodNoun(_ period: BillingPeriod?) -> String? {
        guard let period else { return nil }
        switch period.unit {
        case .day:   return String(localized: "day")
        case .week:  return String(localized: "week")
        case .month: return String(localized: "month")
        case .year:  return String(localized: "year")
        @unknown default: return nil
        }
    }

    // MARK: Actions

    private func purchase() {
        guard let model else { return }
        // Clear first: without this, "Something went wrong" sat under the CTA through every
        // later plan switch and retry, describing an attempt the reader had moved on from.
        message = nil
        Task {
            switch await model.purchaseSelected() {
            case .success:   onSubscribed()
            case .cancelled: break                       // user backed out — say nothing
            case .busy:      break                       // already trying — say nothing
            case .pending:   message = String(localized: "Waiting for approval…")
            case .failed(let error):
                // Log the detail; show our own words. StoreKit's error text is not ours.
                print("[paywall] purchase failed: \(error)")
                message = String(localized: "Something went wrong. Please try again.")
            }
        }
    }

    private func restore() {
        guard let model else { return }
        message = nil
        Task {
            switch await model.restore() {
            case .restored:     onSubscribed()
            case .nothingFound: message = String(localized: "No purchase to restore.")
            case .uncertain:    message = String(localized: "Couldn't check just now. Try again in a moment.")
            case .cancelled:    break                    // backed out of sign-in — say nothing
            case nil:           break                    // already trying — say nothing
            case .failed:       message = String(localized: "Couldn't restore. Please try again.")
            }
        }
    }
}
