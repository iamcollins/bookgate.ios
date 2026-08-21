import SwiftUI

/// Ink emphasis steps. Dark uses alpha on warm white; light darkens ink and, per the
/// handoff, runs "~0.08 heavier" on every de-emphasised step because paper carries no low alpha.
enum Ink {
    case hero, strong, body, secondary, caption, disabled
}

/// A full set of surface tokens for one theme. Light is a *surface remap only* — no screen
/// changes layout, spacing or copy between themes (see README "Design tokens — light theme").
///
/// The night flow (alarm, gate, session, shield, complete) always uses `.dark`, ignoring the
/// user's theme — a white screen at 9pm defeats the product.
struct BGPalette: Equatable {
    let isDark: Bool

    // Floor + ambient
    let base: Color
    /// Radial ambient stops (offset 0…1). Geometry (centre/size) varies per screen; stops never do.
    let ambientStops: [Gradient.Stop]
    /// Warm drifting glow blob colour (alpha baked in). Second blob (copper) below.
    let glowWarm: Color
    let glowCopper: Color

    // Ink
    private let inkBase: UInt32
    private let inkBump: Double   // added to every step on light

    // Brass
    let brassLabel: Color         // uppercase section labels, active tab
    let brassValue: Color         // values, links, chip text
    let brassObjectTop: Color     // bookmark / node / filled-day gradient
    let brassObjectBottom: Color

    // Primary action
    let actionStops: [Gradient.Stop]
    let actionText: Color

    // Glass
    let glassQuiet: Color
    let glassCard: Color
    let glassProminent: Color
    let glassBorder: Color
    let glassInner: Color         // inset top highlight, always present on glass

    // Lines & recesses
    let hairline: Color
    let recess: Color             // empty heatmap cells, placeholder stripes

    // Tab bar chrome. Not on the ink ladder: the handoff sets the inactive tab at cream .4 on
    // dark but ink .58 on light — paper needs far more weight than the ladder's flat +0.08 bump
    // gives, because the bar's own material is nearly the page colour.
    let tabInactive: Color        // inactive tab icon + label

    // Shadows (colour only; radius/offset live on the modifiers)
    let shadowColor: Color

    // Heatmap — four fill weights = session length (never a score)
    let heatmapFills: [Color]

    // MARK: Ink resolution

    func ink(_ step: Ink) -> Color {
        let a: Double
        switch step {
        case .hero:      a = 0.94
        case .strong:    a = 0.85
        case .body:      a = 0.62
        case .secondary: a = 0.50
        case .caption:   a = 0.45
        case .disabled:  a = 0.30
        }
        return Color(hex: inkBase, opacity: min(1, a + inkBump))
    }

    // MARK: Gradients (top → bottom, matching the CSS 180deg)

    var brassObject: LinearGradient {
        LinearGradient(colors: [brassObjectTop, brassObjectBottom], startPoint: .top, endPoint: .bottom)
    }
    var action: LinearGradient {
        LinearGradient(stops: actionStops, startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Dark (default)

    static let dark = BGPalette(
        isDark: true,
        base: Color(hex: 0x100C09),
        ambientStops: [
            .init(color: Color(hex: 0x3B2A1A), location: 0.00),
            .init(color: Color(hex: 0x241A12), location: 0.42),
            .init(color: Color(hex: 0x150F0B), location: 0.78),
            .init(color: Color(hex: 0x100C09), location: 1.00),
        ],
        glowWarm: Color(hex: 0xECB670, opacity: 0.26),
        glowCopper: Color(hex: 0xC67C4A, opacity: 0.20),
        inkBase: 0xF7EFE4,
        inkBump: 0,
        brassLabel: Color(hex: 0xE9B872),
        brassValue: Color(hex: 0xF2D6AB),
        brassObjectTop: Color(hex: 0xF0C68F),
        brassObjectBottom: Color(hex: 0xD79A56),
        actionStops: [
            .init(color: Color(hex: 0xF2CB95), location: 0.00),
            .init(color: Color(hex: 0xDA9E58), location: 0.58),
            .init(color: Color(hex: 0xC0863F), location: 1.00),
        ],
        actionText: Color(hex: 0x241606),
        glassQuiet: Color(hex: 0xFFF0DE, opacity: 0.07),
        glassCard: Color(hex: 0xFFF0DE, opacity: 0.085),
        glassProminent: Color(hex: 0xFFF0DE, opacity: 0.10),
        glassBorder: Color(hex: 0xFFE8CC, opacity: 0.16),
        glassInner: Color(hex: 0xFFF0DC, opacity: 0.20),
        hairline: Color(hex: 0xFFE8CC, opacity: 0.12),
        recess: Color(hex: 0xFFF0DE, opacity: 0.04),
        tabInactive: Color(hex: 0xF7EFE4, opacity: 0.40),
        shadowColor: Color.black,
        heatmapFills: [
            Color(hex: 0xE7AE5C, opacity: 0.35),
            Color(hex: 0xE7AE5C, opacity: 0.50),
            Color(hex: 0xE7AE5C, opacity: 0.70),
            Color(hex: 0xE7AE5C, opacity: 0.90),
        ]
    )

    // MARK: - Light (surface remap)

    static let light = BGPalette(
        isDark: false,
        base: Color(hex: 0xF1E8DA),
        ambientStops: [
            .init(color: Color(hex: 0xFDF6E9), location: 0.00),
            .init(color: Color(hex: 0xF2E8D8), location: 0.46),
            .init(color: Color(hex: 0xE4D8C4), location: 0.78),
            .init(color: Color(hex: 0xE4D8C4), location: 1.00),
        ],
        // The handoff's light frames run the blobs at .22 / .14, not the dark theme's .26 / .20:
        // the same alpha that reads as a lamp in a dark room reads as a stain on paper.
        glowWarm: Color(hex: 0xE2A862, opacity: 0.22),
        glowCopper: Color(hex: 0xC67C4A, opacity: 0.14),
        inkBase: 0x231A12,
        inkBump: 0.08,
        brassLabel: Color(hex: 0x8A5A22),
        brassValue: Color(hex: 0x8A5A22),
        brassObjectTop: Color(hex: 0xE9B872),
        brassObjectBottom: Color(hex: 0xC98F4A),
        actionStops: [
            .init(color: Color(hex: 0xEFC08C), location: 0.00),
            .init(color: Color(hex: 0xD2954F), location: 0.58),
            .init(color: Color(hex: 0xB87A2E), location: 1.00),
        ],
        actionText: Color(hex: 0x2A1A08),
        glassQuiet: Color(hex: 0xFFFCF6, opacity: 0.68),
        glassCard: Color(hex: 0xFFFCF6, opacity: 0.73),
        glassProminent: Color(hex: 0xFFFCF6, opacity: 0.78),
        glassBorder: Color(hex: 0xFFFFFF, opacity: 0.92),
        glassInner: Color(hex: 0xFFFFFF, opacity: 0.90),
        hairline: Color(hex: 0x231A12, opacity: 0.10),
        recess: Color(hex: 0x231A12, opacity: 0.05),
        tabInactive: Color(hex: 0x231A12, opacity: 0.58),
        shadowColor: Color(hex: 0x5A3C1E),
        heatmapFills: [
            Color(hex: 0xC98F4A, opacity: 0.38),
            Color(hex: 0xC98F4A, opacity: 0.55),
            Color(hex: 0xC98F4A, opacity: 0.74),
            Color(hex: 0xC98F4A, opacity: 0.92),
        ]
    )
}
