import SwiftUI

enum GlassLevel {
    case quiet, card, prominent
}

extension View {
    /// Vellum glass: blurred backdrop + warm tint + border + the ever-present inner top highlight.
    /// Warm translucent glass — the design's vellum tint + border + inner top highlight.
    /// `material` (default off) adds SwiftUI's system blur behind the tint; it reads as a cool grey
    /// over the warm base, so it's only worth passing `material: true` for a surface floating over
    /// genuinely busy content (e.g. the tab bar). Everywhere else the warm tint matches the design.
    ///
    /// `shadow` defaults to on for `.prominent` only — the hero panel of a screen, which is the
    /// surface the handoff gives a cast shadow to. The smaller `.card` and `.quiet` surfaces are
    /// left flat until each screen is worked through and matched to its frame; pass `shadow: true`
    /// to lift one early.
    func glass(_ level: GlassLevel = .card, cornerRadius: CGFloat = 22, material: Bool = false,
               shadow: Bool? = nil) -> some View {
        modifier(GlassSurface(level: level, cornerRadius: cornerRadius, material: material,
                              shadow: shadow ?? (level == .prominent)))
    }
}

struct GlassSurface: ViewModifier {
    var level: GlassLevel = .card
    var cornerRadius: CGFloat = 22
    var material: Bool = true
    var shadow: Bool = false
    @Environment(\.bgPalette) private var palette

    private var fill: Color {
        switch level {
        case .quiet:     return palette.glassQuiet
        case .card:      return palette.glassCard
        case .prominent: return palette.glassProminent
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if material {
                    shape
                        .fill(.ultraThinMaterial)  // the blur(20–24px)
                        .overlay(shape.fill(fill)) // the warm tint on top
                } else {
                    shape.fill(fill)               // warm translucent tint only (no grey frost)
                }
            }
            .overlay {
                shape.strokeBorder(palette.glassBorder, lineWidth: 1)
            }
            .overlay {
                // inner top highlight: `inset 0 1px 0 rgba(...)`, always present on glass
                shape
                    .strokeBorder(
                        LinearGradient(colors: [palette.glassInner, .clear],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            }
            .clipShape(shape)
            .background { if shadow { GlassShadow(cornerRadius: cornerRadius, palette: palette) } }
    }
}

/// The cast shadow under a glass panel — `0 26px 60px -22px rgba(0,0,0,.8)` on dark,
/// `0 16px 36px -18px rgba(90,60,30,.3)` on light.
///
/// Not `.shadow()`. That modifier takes its strength from the view's own alpha, and glass runs
/// from 10% (dark) to 78% (light) transparent: the dark panel would have cast almost nothing, and
/// what it did cast would have been shaped by the text inside it rather than by the panel. So the
/// shadow is its own layer — a caster inset by the CSS spread, blurred, offset, then clipped to
/// the region *outside* the panel, which is what an outset `box-shadow` does and what keeps the
/// caster from showing through the translucent glass and dirtying it.
private struct GlassShadow: View {
    let cornerRadius: CGFloat
    let palette: BGPalette

    var body: some View {
        let dark = palette.isDark
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.shadowColor)
            .padding(dark ? 22 : 18)                 // CSS negative spread
            .blur(radius: dark ? 30 : 18)            // CSS blur is ~2× SwiftUI's radius
            .offset(y: dark ? 26 : 16)
            .opacity(dark ? 0.80 : 0.30)
            .clipShape(OutsidePanel(cornerRadius: cornerRadius), style: FillStyle(eoFill: true))
    }
}

/// Everything within reach of the panel except the panel itself, as one even-odd path.
private struct OutsidePanel: Shape {
    let cornerRadius: CGFloat
    var reach: CGFloat = 140

    func path(in rect: CGRect) -> Path {
        var p = Path(rect.insetBy(dx: -reach, dy: -reach))
        p.addPath(Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous))
        return p
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
