import SwiftUI

/// How far a surface lifts off the page. On Liquid Glass this is a *tint* on one shared material,
/// not three thicknesses of it: the old `.07 / .085 / .10` ladder was itself the fake material.
enum GlassLevel {
    case quiet, card, prominent
}

extension View {
    /// Liquid Glass, retuned warm — the system the handoff names ("Pillseal's Liquid Glass
    /// structure, retuned warm … drifting ambient light behind frosted panels").
    ///
    /// This used to hand-build the material: `.ultraThinMaterial` under a warm tint, a hairline
    /// border and an inset top highlight, all transcribed from CSS that had no way to describe
    /// glass which refracts and reflects what moves behind it. `glassEffect` brings the lensing,
    /// the edge highlight, the shadow and the dark-mode behaviour with it, so every one of those
    /// layers is gone — painting them over real glass is what made it read as frosted plastic.
    ///
    /// `interactive` gives the glass the system's press response; pass it for anything tappable.
    func glass(_ level: GlassLevel = .card, cornerRadius: CGFloat = 22,
               interactive: Bool = false) -> some View {
        modifier(GlassSurface(level: level, cornerRadius: cornerRadius, interactive: interactive))
    }

    /// Round Liquid Glass, for the circular controls (play buttons, the back chevron).
    func glassCircle(_ level: GlassLevel = .card, interactive: Bool = true) -> some View {
        modifier(GlassCircle(level: level, interactive: interactive))
    }
}

struct GlassSurface: ViewModifier {
    var level: GlassLevel = .card
    var cornerRadius: CGFloat = 22
    var interactive: Bool = false
    @Environment(\.bgPalette) private var palette

    func body(content: Content) -> some View {
        content.glassEffect(palette.glass(level, interactive: interactive),
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct GlassCircle: ViewModifier {
    var level: GlassLevel = .card
    var interactive: Bool = true
    @Environment(\.bgPalette) private var palette

    func body(content: Content) -> some View {
        content.glassEffect(palette.glass(level, interactive: interactive), in: Circle())
    }
}

/// A theme-aware hairline divider (dividers, timeline spines).
struct Hairline: View {
    var axis: Axis = .horizontal
    @Environment(\.bgPalette) private var palette
    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(width: axis == .vertical ? 1 : nil,
                   height: axis == .horizontal ? 1 : nil)
    }
}
