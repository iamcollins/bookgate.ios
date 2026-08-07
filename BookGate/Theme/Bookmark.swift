import SwiftUI

/// The brass bookmark: a ribbon with a notched foot.
/// CSS `clip-path: polygon(0 0, 100% 0, 100% 100%, 50% 74%, 0 100%)`.
/// The notch depth is 74% by default; the session/complete variants use 76–78%.
struct BookmarkShape: Shape {
    /// Y (0…1) of the notch apex. Larger = shallower notch.
    var notch: CGFloat = 0.74

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * notch))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A filled brass bookmark. Sizes from the handoff: 10×14 chip · 14×19 tab · 19×26 week row ·
/// 26×36 streak card · 38×52 hero · 42×56 shield. It is **never decorative** — a drawn bookmark
/// always means a night that was read.
struct Bookmark: View {
    var width: CGFloat
    var height: CGFloat?
    var notch: CGFloat = 0.74
    /// When false, draws a hairline outline instead of a fill (an unfilled / missed placeholder).
    var filled: Bool = true

    @Environment(\.bgPalette) private var palette

    private var resolvedHeight: CGFloat { height ?? width * 1.37 }

    var body: some View {
        Group {
            if filled {
                BookmarkShape(notch: notch).fill(palette.brassObject)
            } else {
                BookmarkShape(notch: notch)
                    .stroke(palette.hairline, lineWidth: 1.3)
            }
        }
        .frame(width: width, height: resolvedHeight)
        .accessibilityHidden(true)
    }
}
