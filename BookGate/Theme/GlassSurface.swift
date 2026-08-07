import SwiftUI

enum GlassLevel {
    case quiet, card, prominent
}

extension View {
    /// Vellum glass: blurred backdrop + warm tint + border + the ever-present inner top highlight.
    func glass(_ level: GlassLevel = .card, cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassSurface(level: level, cornerRadius: cornerRadius))
    }
}

struct GlassSurface: ViewModifier {
    var level: GlassLevel = .card
    var cornerRadius: CGFloat = 22
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
                shape
                    .fill(.ultraThinMaterial)      // the blur(20–24px)
                    .overlay(shape.fill(fill))     // the warm tint on top
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
