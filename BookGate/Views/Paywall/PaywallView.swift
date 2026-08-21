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

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var model: PaywallModel?
    @State private var message: String?
    /// What StoreKit answered, shown whenever prices did not resolve. Not DEBUG-gated on purpose —
    /// this app is tested through TestFlight, where there are no logs to read. See
    /// `PaywallDiagnostics`; remove before the App Store build.
    /// Only the network-bound half is stored; the rest is read live (see `PaywallDiagnostics`).
    @State private var storeEnvironment = ""
    /// The StoreKit read-out is a support tool, not part of the offer. It now lives one tap inside
    /// the "prices unavailable" notice — still reachable from a TestFlight build with no logs to
    /// read, without putting monospaced debug text on the screen that asks for money.
    @State private var showDiagnostics = false

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
        }
        .task {
            if model == nil { model = PaywallModel(store: services.subscription) }
            // Already entitled when this appears — a restore on a previous launch, or a
            // subscription bought on another device. `onChange` never fires for a state that was
            // already true, which left onboarding's last step with no way forward.
            if services.subscription.entitlement == .entitled { onSubscribed() }
            await model?.load()
            await refreshDiagnostics()
        }
        .onChange(of: services.subscription.entitlement) { _, now in
            if now == .entitled { onSubscribed() }
        }
        .onChange(of: model?.state) { _, _ in
            Task { await refreshDiagnostics() }
        }
    }

    /// The page, laid out once. `tight` only changes the breathing room, never the content — a
    /// small screen shows the same words, closer together.
    private func page(tight: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: tight ? 8 : 16)
            Bookmark(width: 38, height: 52)
            Spacer().frame(height: tight ? 14 : 20)
            Text("Make reading a daily reality.")
                .font(BGFont.serif(tight ? 28 : 31, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 10)
            Text("Your book, your time, your shield — three days on us.")
                .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Only two gaps flex. The offer — timeline then prices — has to read as one block, so
            // the space a tall phone has spare goes above it and below it, never through it.
            Spacer(minLength: tight ? 16 : 22)
            timeline
            Spacer().frame(height: tight ? 12 : 16)
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

    // MARK: Trial timeline (before the price)

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            timelineRow("lock.open", "Today — everything opens", "Full app. First session tonight at 9:00 PM.")
            timelineRow("bell", "Day 2 — we email you", "A day before anything is charged, in writing.")
            timelineRow("creditcard", "Day 3 — your plan begins", "Cancel any time before then and pay nothing.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(.card, cornerRadius: 22)
    }

    private func timelineRow(_ symbol: String, _ day: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.brassValue).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(day).font(BGFont.ui(13.5, .semibold)).foregroundStyle(palette.ink(.strong))
                    .fixedSize(horizontal: false, vertical: true)
                Text(text).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
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
                    Text(billingLine(plan)).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
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

    private var unavailableNotice: some View {
        VStack(spacing: 10) {
            Text("Prices are unavailable right now.")
                .font(BGFont.ui(14, .semibold)).foregroundStyle(palette.ink(.strong))
            Text("Check your connection and try again.")
                .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
            HStack(spacing: 18) {
                Button("Try again") { Task { await model?.retry(); await refreshDiagnostics() } }
                    .font(BGFont.ui(13, .medium)).foregroundStyle(palette.brassValue)
                Button(showDiagnostics ? "Hide details" : "Details") {
                    withAnimation(.easeInOut(duration: 0.2)) { showDiagnostics.toggle() }
                }
                .font(BGFont.ui(13, .medium)).foregroundStyle(palette.ink(.secondary))
            }
            .frame(height: 44)
            if showDiagnostics { diagnosticsPanel }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glass(.card, cornerRadius: 22)
    }

    /// Verbatim, monospaced, selectable — it exists to be read off a screenshot or copied out of
    /// a TestFlight build, not to look nice.
    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STOREKIT").sectionLabel(color: palette.ink(.caption))
            Text(PaywallDiagnostics.live(store: services.subscription)
                    + (storeEnvironment.isEmpty ? "" : "\n" + storeEnvironment))
                .font(BGFont.mono(10))
                .foregroundStyle(palette.ink(.secondary))
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.recess)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1))
        }
    }

    private func refreshDiagnostics() async {
        storeEnvironment = await PaywallDiagnostics.environment()
    }

    private func savingsBadge(_ percent: Int) -> some View {
        Text("SAVE \(percent)%").font(BGFont.ui(9.5, .bold)).tracking(0.8)
            .foregroundStyle(palette.actionText)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(palette.brassObject))
    }

    // MARK: CTA + footer

    private var cta: some View {
        Button { purchase() } label: {
            if model?.isBusy == true { ProgressView().tint(palette.actionText) }
            else { Text(ctaLabel) }
        }
        .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        .disabled(!(model?.canPurchase ?? false))
    }

    private var ctaLabel: String {
        guard let span = model?.selectedPlan.flatMap(freeTrialSpan) else { return String(localized: "Subscribe") }
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

    private var renewalNote: String {
        guard let plan = model?.selectedPlan, let period = periodNoun(plan.period) else { return "" }
        if freeTrialSpan(plan) != nil {
            return String(localized: "Then \(plan.displayPrice) a \(period). Cancel in Settings any time.")
        }
        return String(localized: "\(plan.displayPrice) a \(period). Cancel in Settings any time.")
    }

    // MARK: Copy built from the model's facts
    //
    // Every string below is BookGate's, formatted from `Product.SubscriptionPeriod` /
    // `Product.SubscriptionOffer`. Nothing here may move into the package: a localized string
    // resolved against a package bundle silently returns its key.

    /// "€29.99 a year · €2.50 a month" for a yearly plan; "Billed every month" otherwise.
    private func billingLine(_ plan: PaywallModel.PlanDisplay) -> String {
        if let perMonth = plan.pricePerMonth, let period = periodNoun(plan.period) {
            return String(localized: "\(plan.displayPrice) a \(period) · \(perMonth) a month")
        }
        guard let period = periodNoun(plan.period) else { return plan.displayPrice }
        return String(localized: "Billed every \(period)")
    }

    /// The big figure: a yearly plan is quoted per month so the two cards compare honestly.
    private func unitPrice(_ plan: PaywallModel.PlanDisplay) -> String {
        plan.pricePerMonth ?? plan.displayPrice
    }

    private func unitCaption(_ plan: PaywallModel.PlanDisplay) -> String? {
        if plan.pricePerMonth != nil { return String(localized: "per month") }
        guard let period = periodNoun(plan.period) else { return nil }
        return String(localized: "per \(period)")
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
        Task {
            switch await model.purchaseSelected() {
            case .success:   onSubscribed()
            case .cancelled: break                       // user backed out — say nothing
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
        Task {
            switch await model.restore() {
            case .restored:     onSubscribed()
            case .nothingFound: message = String(localized: "No purchase to restore.")
            case .cancelled:    break                    // backed out of sign-in — say nothing
            case .failed:       message = String(localized: "Couldn't restore. Please try again.")
            }
        }
    }
}
