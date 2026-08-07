import SwiftUI

/// Typography per the handoff. Two families: **Newsreader** (serif) for display, titles, book
/// titles and all large numerals; **SF Pro / system** for UI. Timecodes use a monospaced face.
///
/// Sizes are fixed for now to hold the tight layouts pixel-accurate; Dynamic Type is a tracked
/// open item (see README "Accessibility") and will be layered on with `relativeTo:` later.
enum BGFont {
    static let serifFamily = "Newsreader"

    // MARK: Serif (Newsreader)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(serifFamily, fixedSize: size).weight(weight)
    }
    static func serifItalic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(serifFamily, fixedSize: size).weight(weight).italic()
    }

    // MARK: UI (SF Pro / system)

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Named display roles (serif)

    static let screenTitle = serif(33, .medium)     // Library / Takeaways / titles 31–33 / 500
    static let sheetTitle  = serif(27, .medium)
    static let numeralHero = serif(72, .medium)     // streak
    static let numeralXL   = serif(44, .medium)     // totals
    static let sessionClock = serif(30, .regular)   // remaining time
    static func aside(_ size: CGFloat = 14) -> Font { serifItalic(size, .regular) } // italic asides

    // MARK: Named UI roles

    static let row       = ui(15.5, .semibold)      // list rows 15–16 / 600
    static let rowStrong = ui(16, .semibold)
    static let body      = ui(13.5, .regular)       // body 12.5–14.5 / 400
    static let button    = ui(16.5, .semibold)      // buttons 15.5–17 / 650 (approx w/ semibold)
    static let caption   = ui(12.5, .regular)
}

extension View {
    /// 10px / 600 uppercase, 1.4px tracking, brass — the handoff's section label.
    func sectionLabel(color: Color? = nil) -> some View {
        modifier(SectionLabelStyle(overrideColor: color))
    }
}

private struct SectionLabelStyle: ViewModifier {
    var overrideColor: Color?
    @Environment(\.bgPalette) private var palette
    func body(content: Content) -> some View {
        content
            .font(BGFont.ui(10, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(overrideColor ?? palette.brassLabel)
    }
}
