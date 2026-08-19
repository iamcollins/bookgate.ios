import SwiftUI

/// The evening sky for the reading-time picker — a pure function of the chosen minute-of-day.
///
/// One rising **moon** over a warm dusk that deepens to espresso night as the hour gets later.
/// There is deliberately **no sun body**: a single vertical drag can't make a sun set *down* and
/// a moon rise *up* at once (opposite motions), so the early hours are just a warm amber horizon
/// **glow** that fades. Pure SwiftUI (gradients + radial glows) in warm brand tones — not photoreal.
struct ReadingSkyStage: View, Animatable {
    /// Minute-of-day (as a Double so SwiftUI can interpolate it smoothly during the load auto-rise
    /// and between scrub steps). Drives darkness, moon altitude, glow, stars.
    var minute: Double
    /// When false, the sky is drawn without the moon (used where another object is the hero).
    var showMoon: Bool = true

    // Interpolate `minute` frame-by-frame under `withAnimation` — the smooth rise, done the SwiftUI way.
    var animatableData: Double {
        get { minute }
        set { minute = newValue }
    }

    /// Where the warm horizon glow sits, as a fraction of the stage height (low, in the golden band).
    private let glowY: CGFloat = 0.64
    /// The moon rides the upper sky, above the centred time numeral, so it never washes over the
    /// digits: low at early evening, rising to the top by midnight.
    private let moonLowY: CGFloat = 0.40
    private let moonHighY: CGFloat = 0.13

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let n = ReadingSky.nightness(minute: minute)
            let size = geo.size
            // Moon stays hidden while it's still bright (16:00–~17:00), then fades in as it gets dark.
            let rr = min(max((n - 0.15) / 0.32, 0), 1)
            let moonReveal = rr * rr * (3 - 2 * rr)
            ZStack {
                // 1 — sky gradient, warm dusk → espresso as night deepens
                LinearGradient(colors: [ReadingSky.top(n), ReadingSky.bottom(n)],
                               startPoint: .top, endPoint: .bottom)

                // 2 — warm horizon glow (golden-hour light of the early hours; gone by deep night)
                let glowOpacity = pow(1 - n, 1.35)
                Ellipse()
                    .fill(RadialGradient(colors: [ReadingSky.glow(n).opacity(glowOpacity), .clear],
                                         center: .center, startRadius: 0, endRadius: size.width * 0.6))
                    .frame(width: size.width * 1.6, height: size.height * 0.6)
                    .position(x: size.width * 0.5, y: size.height * glowY)
                    .blur(radius: 26)
                    .allowsHitTesting(false)

                // 3 — stars, fading in after dusk
                StarField(nightness: n, size: size)

                // 4 — the moon: the only celestial body, rising with nightness
                if showMoon {
                    Moon(nightness: n, reduceMotion: reduceMotion)
                        .opacity(moonReveal)
                        .position(x: size.width * 0.72,
                                  y: size.height * (moonLowY - CGFloat(n) * (moonLowY - moonHighY)))
                }
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Moon

private struct Moon: View {
    var nightness: Double
    var reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        // A pale bone-grey moon (not a golden sun): warm-toned but clearly desaturated, cooler as it
        // climbs into the dark. The halo is a soft warm-white, not amber.
        let core = ReadingSky.lerpHex(0xE7E0D2, 0xEFEADE, nightness)
        let edge = ReadingSky.lerpHex(0xB1A794, 0xC4BAA6, nightness)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xEADFC6, opacity: 0.42), .clear],
                                     center: .center, startRadius: 0, endRadius: 62))
                .frame(width: 156, height: 156)
                .blur(radius: 18)
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.06 : 0.97))
            Circle()
                .fill(RadialGradient(colors: [core, edge],
                                     center: UnitPoint(x: 0.40, y: 0.38),
                                     startRadius: 2, endRadius: 44))
                .frame(width: 70, height: 70)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1).blendMode(.plusLighter))
        }
        .shadow(color: Color(hex: 0xEADFC6, opacity: 0.28 * nightness), radius: 22)
        .animation(reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .allowsHitTesting(false)
    }
}

// MARK: - Stars

private struct StarField: View {
    var nightness: Double
    var size: CGSize

    /// Fixed positions (unit space) so the field is stable across renders. Kept to the upper sky.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, base: Double)] = [
        (0.14, 0.16, 1.3, 0.9), (0.26, 0.28, 1.0, 0.7), (0.38, 0.10, 1.1, 0.85),
        (0.52, 0.22, 1.0, 0.8), (0.61, 0.09, 1.3, 0.95), (0.72, 0.26, 1.0, 0.7),
        (0.84, 0.15, 1.3, 0.9), (0.90, 0.32, 0.9, 0.6), (0.20, 0.38, 0.9, 0.55),
        (0.45, 0.36, 1.0, 0.7), (0.79, 0.40, 0.9, 0.6), (0.33, 0.20, 0.9, 0.6),
    ]

    var body: some View {
        // Appear after dusk (~n 0.5) and reach full by deep night.
        let reveal = min(max((nightness - 0.5) / 0.4, 0), 1)
        ZStack {
            ForEach(0..<Self.stars.count, id: \.self) { i in
                let s = Self.stars[i]
                Circle()
                    .fill(Color(hex: 0xFDF4E3))
                    .frame(width: s.r * 2, height: s.r * 2)
                    .opacity(reveal * s.base)
                    .position(x: size.width * s.x, y: size.height * s.y)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Palette

/// The warm sky palette + time→darkness curve. All stops live in BookGate's espresso→copper→amber
/// family, interpolated in sRGB (the design's colour space) between keyframes.
enum ReadingSky {
    private struct Key { let n: Double; let top: UInt32; let bottom: UInt32; let glow: UInt32 }

    /// Keyframes by `nightness` (0 = bright 16:00 … 1 = darkest 00:00). Brightness steps down at each
    /// key so the darkening reads evenly across the evening rather than all at once late on.
    private static let keys: [Key] = [
        Key(n: 0.00, top: 0x3A2A1A, bottom: 0xC88A4A, glow: 0xECB670),
        Key(n: 0.25, top: 0x2C2015, bottom: 0x9A5E2A, glow: 0xD0913F),
        Key(n: 0.50, top: 0x201710, bottom: 0x5E3E1E, glow: 0xA96C34),
        Key(n: 0.75, top: 0x150F0A, bottom: 0x30200F, glow: 0x6E4926),
        Key(n: 1.00, top: 0x0B0806, bottom: 0x100C09, glow: 0x3B2A1A),
    ]

    /// Darkness of the sky across the allowed reading window **16:00 → 00:00**: 0 (bright, moon
    /// hidden) at 16:00, easing to 1 (deep night, moon at the top) at midnight. Midnight is stored as
    /// `readingMin == 0`; everything is clamped into the window so there's no 24-hour wrap.
    static let windowStart = 960.0    // 16:00
    static let windowEnd   = 1440.0   // 00:00 (next day)
    static let duskAnchor  = 1140.0   // 19:00 — already dark dusk by here
    static let fullDark    = 1380.0   // 23:00 — darkest reached here, then held

    /// Darkness rises **fast** early: brightest at 16:00, hitting a dark dusk by 19:00, the darkest
    /// by 23:00, and simply holding at the darkest from 23:00 to midnight. So 21:00 is already deep.
    /// Int convenience: midnight is stored as 0, so treat it as the darkest end.
    static func nightness(_ readingMin: Int) -> Double {
        nightness(minute: readingMin == 0 ? windowEnd : Double(readingMin))
    }

    static func nightness(minute: Double) -> Double {
        let scrub = min(max(minute, windowStart), windowEnd)
        if scrub <= duskAnchor {                       // 16:00 → 19:00: bright → dark dusk
            return 0.62 * (scrub - windowStart) / (duskAnchor - windowStart)
        } else if scrub <= fullDark {                  // 19:00 → 23:00: dark dusk → darkest
            return 0.62 + 0.38 * (scrub - duskAnchor) / (fullDark - duskAnchor)
        } else {                                       // 23:00 → 00:00: hold at the darkest
            return 1.0
        }
    }

    static func top(_ n: Double) -> Color { color(n) { $0.top } }
    static func bottom(_ n: Double) -> Color { color(n) { $0.bottom } }
    static func glow(_ n: Double) -> Color { color(n) { $0.glow } }

    private static func color(_ n: Double, _ pick: (Key) -> UInt32) -> Color {
        let c = min(max(n, 0), 1)
        var lo = keys[0], hi = keys[keys.count - 1]
        for i in 0..<(keys.count - 1) where c >= keys[i].n && c <= keys[i + 1].n {
            lo = keys[i]; hi = keys[i + 1]; break
        }
        let span = hi.n - lo.n
        let t = span <= 0 ? 0 : (c - lo.n) / span
        return lerpHex(pick(lo), pick(hi), t)
    }

    /// Linear sRGB interpolation between two 24-bit hex colours.
    static func lerpHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func ch(_ x: UInt32, _ shift: UInt32) -> Double { Double((x >> shift) & 0xff) }
        let r = ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t
        let g = ch(a, 8)  + (ch(b, 8)  - ch(a, 8))  * t
        let bl = ch(a, 0) + (ch(b, 0)  - ch(a, 0))  * t
        return Color(.sRGB, red: r / 255, green: g / 255, blue: bl / 255, opacity: 1)
    }
}
