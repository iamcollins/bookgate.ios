import SwiftUI
import StoreKit
import SubscriptionKit

/// The subscription section of Settings.
///
/// A subscription app has to be able to answer three questions from inside itself: *what am I on*,
/// *when does it renew*, and *how do I stop*. Settings previously answered none of them — the only
/// mention of a subscription anywhere in the app was the paywall that sold it. Apple's review
/// guidelines expect the first two, and a reader who cannot find the third stops trusting the app.
///
/// Everything factual comes from SubscriptionKit (`entitlements`, `billingStatus`); the wording is
/// BookGate's, and cancelling is handed to Apple's own sheet — the only place a subscription can
/// actually be changed.
struct SubscriptionCard: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    @State private var showManage = false
    @State private var message: String?
    @State private var restoring = false

    private var store: SubscriptionStore { services.subscription }

    /// This user's own entitlement — a family-shared one is theirs to use but not to manage.
    private var detail: EntitlementDetail? {
        store.entitlements.first { !$0.isFamilyShared } ?? store.entitlements.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Subscription").sectionLabel()
            VStack(spacing: 12) {
                statusRow
                if let note = billingNote {
                    Divider().overlay(palette.hairline)
                    warning(note)
                }
                Divider().overlay(palette.hairline)
                actions
                if let message {
                    Text(message).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glass(.card, cornerRadius: 20)
        .manageSubscriptionsSheet(isPresented: $showManage)
        .task { _ = await store.refreshEntitlement() }
    }

    // MARK: Status

    private var statusRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(planTitle).font(BGFont.row).foregroundStyle(palette.ink(.strong))
                Text(planDetail).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
            }
            Spacer(minLength: 12)
            if store.isEntitled {
                Text(detail?.isIntroductoryOffer == true ? "TRIAL" : "ACTIVE")
                    .font(BGFont.ui(9.5, .bold)).tracking(0.8)
                    .foregroundStyle(palette.actionText)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(palette.brassObject))
            } else if let lapse = store.lapse, lapse.reason != .neverSubscribed {
                Text("ENDED")
                    .font(BGFont.ui(9.5, .bold)).tracking(0.8)
                    .foregroundStyle(palette.ink(.secondary))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
            }
        }
    }

    private var planTitle: String {
        guard store.isEntitled else {
            guard let lapse = store.lapse, lapse.reason != .neverSubscribed else {
                return String(localized: "No subscription")
            }
            return String(localized: "Subscription ended")
        }
        guard let id = detail?.productID else { return String(localized: "BookGate") }
        switch id {
        case AppSubscription.yearlyID:  return String(localized: "BookGate · Yearly")
        case AppSubscription.monthlyID: return String(localized: "BookGate · Monthly")
        default: return String(localized: "BookGate")
        }
    }

    private var planDetail: String {
        guard store.isEntitled else {
            guard let lapse = store.lapse else {
                return String(localized: "Your reading alarm needs an active plan.")
            }
            return LapseCopy.settingsDetail(lapse, planName: lapsedPlanName)
        }
        if detail?.isFamilyShared == true {
            return String(localized: "Shared with you through Family Sharing.")
        }
        guard let expires = detail?.expirationDate else {
            return String(localized: "Active.")
        }
        // A bare date is useless when the date is today — a sandbox subscription renewing
        // in five minutes read as "Renews 21 August", which is exactly how a mid-session
        // lapse looked like an app bug rather than an expiry.
        let when = LapseCopy.precise(expires)
        if detail?.isIntroductoryOffer == true {
            // The one date that matters during a trial is the day money starts.
            return String(localized: "Free until \(when), then it renews.")
        }
        return String(localized: "Renews \(when).")
    }

    private var lapsedPlanName: String? {
        switch store.lapse?.productID {
        case AppSubscription.yearlyID:  return String(localized: "Yearly plan")
        case AppSubscription.monthlyID: return String(localized: "Monthly plan")
        default: return nil
        }
    }

    private var billingNote: String? {
        switch store.billingStatus {
        case .ok: return nil
        case .billingRetry:
            return String(localized: "Your last payment didn't go through. Update your payment method to keep tonight's shield.")
        case .gracePeriod:
            return String(localized: "There's a problem with your payment method. Everything still works for now.")
        }
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.brassValue)
            Text(text).font(BGFont.caption).foregroundStyle(palette.ink(.body))
            Spacer(minLength: 0)
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            row(String(localized: "Manage subscription"),
                String(localized: "Change plan or cancel, in the App Store.")) {
                showManage = true
            }
            Divider().overlay(palette.hairline)
            row(String(localized: "Restore purchases"),
                String(localized: "Already subscribed on another device?"),
                busy: restoring) {
                restore()
            }
        }
    }

    private func row(_ title: String, _ subtitle: String, busy: Bool = false,
                     _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BGFont.row).foregroundStyle(palette.ink(.strong))
                    Text(subtitle).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                }
                Spacer(minLength: 0)
                if busy {
                    ProgressView().tint(palette.brassValue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.ink(.secondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func restore() {
        restoring = true
        message = nil
        Task {
            switch await store.restore() {
            case .restored:     message = String(localized: "Restored. You're all set.")
            case .nothingFound: message = String(localized: "No purchase to restore on this Apple Account.")
            case .cancelled:    break                  // backed out of sign-in — say nothing
            case .failed:       message = String(localized: "Couldn't restore. Please try again.")
            }
            restoring = false
        }
    }
}
