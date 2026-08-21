import XCTest
import SubscriptionKit
@testable import BookGate

/// BookGate's words for a subscription that ended.
///
/// Two things here have already gone wrong once and are worth pinning: a bare date is
/// useless when the date is today (a sandbox subscription renewing in five minutes read as
/// "Renews 21 August", which made a real expiry look like an app bug), and a failed payment
/// must never be answered with a sales pitch.
final class LapseCopyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: The date

    func testAnExpiryInsideADayShowsTheTime() {
        let inFiveMinutes = now.addingTimeInterval(300)
        let text = LapseCopy.precise(inFiveMinutes, now: now)
        XCTAssertFalse(text.contains("November"),
                       "a date alone cannot distinguish 'in five minutes' from 'in a month'")
    }

    func testAnExpiryLastWeekShowsTheDate() {
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        XCTAssertEqual(LapseCopy.precise(lastWeek, now: now), LapseCopy.dayMonth(lastWeek))
    }

    func testAnExpiryJustPassedStillShowsTheTime() {
        // Symmetric: five minutes ago is as ambiguous as five minutes ahead.
        let justGone = now.addingTimeInterval(-300)
        XCTAssertNotEqual(LapseCopy.precise(justGone, now: now), LapseCopy.dayMonth(justGone))
    }

    // MARK: The right response to the right reason

    func testOnlyABillingFailureAsksForAPaymentFix() {
        XCTAssertTrue(LapseCopy.needsPaymentFix(.init(reason: .billingFailed)))
        for reason: EntitlementLapse.Reason in [.cancelled, .expired, .refunded,
                                                .neverSubscribed, .productUnavailable,
                                                .priceIncreaseDeclined] {
            XCTAssertFalse(LapseCopy.needsPaymentFix(.init(reason: reason)),
                           "\(reason) is not fixed by updating a card")
        }
    }

    /// A first-time visitor gets the pitch; everyone else gets an explanation.
    func testFirstRunKeepsTheSalesHeadlineAndOthersDoNot() {
        XCTAssertEqual(LapseCopy.title(.neverSubscribed),
                       String(localized: "Make reading a daily reality."))
        for reason: EntitlementLapse.Reason in [.cancelled, .expired, .billingFailed, .refunded] {
            XCTAssertNotEqual(LapseCopy.title(.init(reason: reason)),
                              String(localized: "Make reading a daily reality."),
                              "\(reason) deserves to be told what happened")
        }
    }

    /// The lapse copy reassures before it sells — the fear on that screen is losing a streak.
    func testALapseSaysNothingWasLost() {
        let lapse = EntitlementLapse(reason: .cancelled, endedAt: now.addingTimeInterval(-86_400))
        let text = LapseCopy.detail(lapse, planName: "monthly plan")
        XCTAssertTrue(text.contains("still here"), "got: \(text)")
        XCTAssertTrue(text.contains("monthly plan"), "the plan that ended should be named")
    }

    func testABillingFailureTellsThemHowToFixIt() {
        let text = LapseCopy.detail(.init(reason: .billingFailed), planName: nil)
        XCTAssertTrue(text.lowercased().contains("payment method"), "got: \(text)")
    }
}
