import SwiftUI

/// The "lamp in the dark" backdrop: the base floor, the elliptical ambient wash, and up to two
/// slow-drifting glow blobs. Geometry (centre/size) varies per screen; the colour stops never do.
///
/// Motion: blobs `drift` (18–23s) — translate ±6% and scale 1→1.15. Honours Reduce Motion by
/// **freezing** the animation (blobs stay, they just don't move), per the handoff.
struct BGAmbientBackground: View {
    /// Centre of the ambient wash, in unit space (CSS default is 50% / -8%).
    var center: UnitPoint = UnitPoint(x: 0.5, y: -0.08)
    /// Ambient radii as fractions of the frame's own width and height — the CSS `125% 80%`.
    /// Per-axis, because the wash is far wider than the screen but only ~4/5 of its height.
    var radiusX: CGFloat = 1.25
    var radiusY: CGFloat = 0.80
    /// Show the drifting glow blobs on top of the wash. Max two, always.
    var showGlow: Bool = true
    /// Nudge the two blobs' home positions for variety per screen.
    var warmAnchor: UnitPoint = UnitPoint(x: 0.28, y: 0.30)
    var copperAnchor: UnitPoint = UnitPoint(x: 0.78, y: 0.62)

    @Environment(\.bgPalette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack {
                palette.base
                // CSS is `radial-gradient(125% 80% at 50% -8%, …)`: two radii, one per axis, each
                // a fraction of the box. `EllipticalGradient` takes a single fraction of the
                // ellipse inscribed in its frame, so the vertical radius sets that fraction and
                // the wider horizontal one is bought by drawing into an over-wide frame and
                // clipping back. Folding both axes into one 0.95 was what killed the wash: it
                // reached its last stop at 40% of the screen, and everything below — the whole
                // lower half of Today — was one flat colour. Unreadable as depth on paper.
                EllipticalGradient(
                    stops: palette.ambientStops,
                    center: center,
                    endRadiusFraction: radiusY * 2
                )
                .frame(width: geo.size.width * (radiusX / radiusY), height: geo.size.height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                if showGlow {
                    GlowBlob(color: palette.glowWarm, diameter: 320, anchor: warmAnchor,
                             period: 21, drift: 0.06, size: geo.size)
                    GlowBlob(color: palette.glowCopper, diameter: 300, anchor: copperAnchor,
                             period: 18, drift: 0.055, size: geo.size, reversed: true)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct GlowBlob: View {
    let color: Color
    let diameter: CGFloat
    let anchor: UnitPoint
    let period: Double
    let drift: CGFloat
    let size: CGSize
    var reversed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        let dx = size.width * drift * (reversed ? -1 : 1)
        let dy = size.height * drift * 0.6
        Circle()
            .fill(
                RadialGradient(colors: [color, .clear],
                               center: .center,
                               startRadius: 0,
                               endRadius: diameter * 0.31) // transparent by ~62%
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 32)
            .position(x: size.width * anchor.x, y: size.height * anchor.y)
            .offset(x: animate ? dx : -dx, y: animate ? dy : -dy)
            .scaleEffect(animate ? 1.15 : 1.0)
            .animation(reduceMotion ? nil :
                        .easeInOut(duration: period).repeatForever(autoreverses: true),
                       value: animate)
            .onAppear { if !reduceMotion { animate = true } }
    }
}
