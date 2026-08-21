import Foundation
import SubscriptionKit

/// BookGate's words for a subscription that has ended.
///
/// SubscriptionKit establishes *what* happened — cancelled, payment failed, refunded, and
/// when. It deliberately says nothing about how to word it: a `String(localized:)` inside a
/// package silently returns its key in every non-English locale, and the voice belongs to
/// the app anyway.
///
/// The distinction that matters most here is **cancelled versus billing failure**. Someone
/// who cancelled chose to leave, and an offer is a fair thing to show them. Someone whose
/// card expired did not choose anything, and answering that with "Make reading a daily
/// reality" reads as a shop assistant who hasn't noticed you're already a customer.
enum LapseCopy {

    /// The headline. Short, factual, and never blaming the reader.
    static func title(_ lapse: EntitlementLapse) -> String {
        switch lapse.reason {
        case .neverSubscribed:
            return String(localized: "Make reading a daily reality.")
        case .billingFailed:
            return String(localized: "Your payment didn't go through.")
        case .refunded:
            return String(localized: "Your subscription was refunded.")
        case .priceIncreaseDeclined:
            return String(localized: "Your plan ended when the price changed.")
        case .productUnavailable:
            return String(localized: "That plan isn't available any more.")
        case .cancelled, .expired:
            return String(localized: "Your reading plan has ended.")
        }
    }

    /// One line under the headline. Says what to do, or what happens next.
    static func detail(_ lapse: EntitlementLapse, planName: String?) -> String {
        let plan = planName ?? String(localized: "plan")
        switch lapse.reason {
        case .neverSubscribed:
            return String(localized: "Your book, your time, your shield — three days on us.")

        case .billingFailed:
            // The one case where the fix is not "buy something" — and not ours to build.
            return String(localized: "Your subscription is still there. Manage it in the App Store to carry on.")

        case .refunded:
            return String(localized: "Start again whenever you'd like to.")

        case .priceIncreaseDeclined, .productUnavailable:
            return String(localized: "Here's what's available now.")

        case .cancelled, .expired:
            // Deliberately does NOT promise that their library and streak are intact. That
            // read well until you remember this same screen appears after a delete and
            // reinstall, where every one of those things is gone — the app would be
            // reassuring someone about data it had just lost.
            if let ended = lapse.endedAt {
                return String(localized: "Your \(plan) ended on \(dayMonth(ended)).")
            }
            return String(localized: "Pick up where you left off whenever you like.")
        }
    }

    /// The Settings row: what the reader needs to know at a glance.
    static func settingsDetail(_ lapse: EntitlementLapse, planName: String?) -> String {
        switch lapse.reason {
        case .neverSubscribed:
            return String(localized: "Your reading alarm needs an active plan.")
        case .billingFailed:
            return String(localized: "The last payment failed. Update your payment method to carry on.")
        case .refunded:
            return String(localized: "Refunded.")
        case .priceIncreaseDeclined:
            return String(localized: "Ended when the price changed.")
        case .productUnavailable:
            return String(localized: "This plan is no longer sold.")
        case .cancelled, .expired:
            guard let ended = lapse.endedAt else { return String(localized: "Ended.") }
            return String(localized: "\(planName ?? String(localized: "Your plan")) ended \(precise(ended)).")
        }
    }

    /// Whether the primary action should be "fix the payment" rather than "subscribe".
    static func needsPaymentFix(_ lapse: EntitlementLapse) -> Bool {
        lapse.reason == .billingFailed
    }

    // MARK: Dates

    /// "21 August" — enough for something that ended a while ago.
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    /// A date is not enough when it is *today*. A sandbox subscription that renews in five
    /// minutes rendered as "Renews 21 August", which is how a lapse mid-testing looked like
    /// a bug for an hour. Inside a day, say the time.
    static func precise(_ date: Date, now: Date = .now) -> String {
        if abs(date.timeIntervalSince(now)) < 24 * 3600 {
            return date.formatted(.dateTime.hour().minute())
        }
        return dayMonth(date)
    }
}
