import SwiftUI

/// The paywall (screen 8f). No free tier: a 3-day trial, then subscription. The **timeline is
/// stated before the price** (today / day 2 / day 3), yearly is preselected, the savings badge is
/// **computed** from real prices, and there is one CTA. Used as onboarding's last step and as the
/// lapsed hard wall (no dismiss — `onBack` is nil; never shown while an alarm rings).
///
/// NOTE: the trial-timeline wording is **regulated** and the prices are placeholders — both need
/// legal/store sign-off before shipping (flagged in the handoff's Open items).
struct PaywallView: View {
    /// Called when an entitlement is active (purchase or restore).
    var onSubscribed: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var selected: String?
    @State private var message: String?

    private var sub: SubscriptionStore { services.subscription }
    private var plans: [SubscriptionStore.PlanDisplay] { sub.plans }
    private var selectedPlan: SubscriptionStore.PlanDisplay? { plans.first { $0.id == selected } ?? plans.first }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.12))
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 20)
                    Bookmark(width: 38, height: 52)
                    Text("Make reading a daily reality.")
                        .font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
                        .multilineTextAlignment(.center)
                    Text("Your book, your time, your shield — three days on us.")
                        .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                        .multilineTextAlignment(.center)

                    timeline
                    planCards
                    cta

                    if let message {
                        Text(message).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    }
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            if sub.plans.isEmpty { await sub.bootstrap() }
            selected = plans.first(where: { $0.id == SubscriptionStore.yearlyID })?.id ?? plans.first?.id
        }
        .onChange(of: sub.isSubscribed) { _, now in if now { onSubscribed() } }
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
                Text(text).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
            }
        }
    }

    // MARK: Plan cards

    private var planCards: some View {
        VStack(spacing: 12) {
            ForEach(plans) { plan in planCard(plan) }
        }
    }

    private func planCard(_ plan: SubscriptionStore.PlanDisplay) -> some View {
        let isOn = plan.id == (selected ?? selectedPlan?.id)
        let isYearly = plan.id == SubscriptionStore.yearlyID
        return Button { selected = plan.id } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.name).font(BGFont.ui(16, .semibold)).foregroundStyle(palette.ink(.hero))
                        if isYearly, let pct = sub.yearlySavingsPercent {
                            badge("SAVE \(pct)%")
                        }
                    }
                    Text("\(plan.price) / \(plan.period)")
                        .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                }
                Spacer()
                if isYearly { Text("Recommended").sectionLabel(color: palette.ink(.secondary)) }
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(isOn ? palette.brassValue : palette.ink(.disabled))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.glassCard)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isOn ? palette.brassLabel : palette.glassBorder, lineWidth: isOn ? 1.6 : 1))
            }
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(BGFont.ui(9.5, .bold)).tracking(0.6)
            .foregroundStyle(palette.actionText)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(palette.brassObject))
    }

    // MARK: CTA + footer

    private var cta: some View {
        Button { purchase() } label: {
            if sub.working { ProgressView().tint(palette.actionText) }
            else { Text(ctaLabel) }
        }
        .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        .disabled(sub.working || selectedPlan == nil)
    }

    private var ctaLabel: String {
        (selectedPlan?.trial != nil) ? String(localized: "Start my 3 free days") : String(localized: "Subscribe")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(renewalNote).font(BGFont.ui(11, .regular)).foregroundStyle(palette.ink(.caption))
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore") { restore() }.font(BGFont.ui(12, .medium)).foregroundStyle(palette.brassValue)
                Link("Terms", destination: Legal.termsURL).font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
                Link("Privacy", destination: Legal.privacyURL).font(BGFont.ui(12, .medium)).tint(palette.ink(.secondary))
            }
        }
        .padding(.top, 6)
    }

    private var renewalNote: String {
        guard let plan = selectedPlan else { return "" }
        if plan.trial != nil {
            return String(localized: "Then \(plan.price) a \(plan.period). Cancel in Settings any time.")
        }
        return String(localized: "\(plan.price) a \(plan.period). Cancel in Settings any time.")
    }

    // MARK: Actions

    private func purchase() {
        guard let plan = selectedPlan else { return }
        Task {
            let outcome = await sub.purchase(plan)
            switch outcome {
            case .success: onSubscribed()
            case .cancelled: break
            case .pending: message = String(localized: "Waiting for approval…")
            case .failed: message = String(localized: "Something went wrong. Please try again.")
            }
        }
    }

    private func restore() {
        Task {
            let outcome = await sub.restore()
            switch outcome {
            case .restored: onSubscribed()
            case .nothingFound: message = String(localized: "No purchase to restore.")
            case .failed: message = String(localized: "Couldn't restore. Please try again.")
            }
        }
    }
}
