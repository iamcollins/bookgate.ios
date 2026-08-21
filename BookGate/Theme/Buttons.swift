import SwiftUI

/// One primary action per screen. Filled brass action gradient, dark ink, action-shadow.
/// Every button is a **min-height box with centred wrapping text** (44pt min; 48–58 typical) —
/// never a fixed single-line height (handoff rule 7 + Localisation: German wraps, never shrinks).
struct PrimaryActionButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 56
    var cornerRadius: CGFloat = 18
    @Environment(\.bgPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(BGFont.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.actionText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(shape.fill(palette.action))
            .overlay(shape.strokeBorder(Color.white.opacity(0.5), lineWidth: 1).blendMode(.plusLighter))
            .clipShape(shape)
            .shadow(color: palette.shadowColor.opacity(palette.isDark ? 0.55 : 0.30),
                    radius: 15, x: 0, y: 14)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary action: glass fill, ink text. Used for "Snooze", "keep it", "Not now"-adjacent.
struct GlassButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 52
    var cornerRadius: CGFloat = 18
    @Environment(\.bgPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BGFont.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.ink(.strong))
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .glass(.card, cornerRadius: cornerRadius, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet text button: no fill. Used for "Skip Today", "End Early", "Not now".
struct TextButtonStyle: ButtonStyle {
    var ink: Ink = .body
    var minHeight: CGFloat = 44
    @Environment(\.bgPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BGFont.ui(15.5, .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.ink(ink))
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
