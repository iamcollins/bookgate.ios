import UIKit

/// The app's whole haptic vocabulary, in one place so the night flow feels consistent and stays
/// quiet. BookGate is a bedtime app: haptics mark the three moments that genuinely deserve a nudge
/// (the gate opening, the goal being reached, a night recorded) and nothing else. No taps on
/// ordinary buttons — a phone buzzing at 9pm for every tap is the opposite of calm.
@MainActor
enum Haptics {

    /// The camera gate recognised you and your book.
    static func gateOpened() { notify(.success) }

    /// The reading goal was reached mid-session — often felt through a pocket or a duvet, which is
    /// exactly why it is a haptic and not a sound.
    static func goalReached() { notify(.success) }

    /// A night was recorded.
    static func success() { notify(.success) }

    /// A soft selection tick, for the few places a choice changes state under the finger.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
