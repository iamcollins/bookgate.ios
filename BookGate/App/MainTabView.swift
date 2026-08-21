import SwiftUI

enum BGTab: Int, CaseIterable, Identifiable {
    case today, library, takeaways, progress
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .today:     return String(localized: "Today")
        case .library:   return String(localized: "Library")
        case .takeaways: return String(localized: "Takeaways")
        case .progress:  return String(localized: "Progress")
        }
    }
    /// SF Symbol for the non-Today tabs; Today draws the brass bookmark instead.
    var symbol: String {
        switch self {
        case .today:     return "bookmark.fill"
        case .library:   return "books.vertical.fill"
        case .takeaways: return "waveform"
        case .progress:  return "square.grid.3x3.fill"
        }
    }
}

/// The four-tab shell with a floating glass tab bar. Content sits behind the bar (the ambient runs
/// full-bleed); each screen owns its own scroll + bottom inset.
struct MainTabView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var tab: BGTab

    /// `initialTab` is for the screenshot harness, which mounts one shell per tab in a single
    /// process; the app itself always opens on Today (or `BOOKGATE_TAB` while debugging).
    init(initialTab: BGTab? = nil) {
        _tab = State(initialValue: initialTab ?? Self.defaultTab)
    }

    private static var defaultTab: BGTab {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["BOOKGATE_TAB"] {
        case "library": return .library
        case "takeaways": return .takeaways
        case "progress": return .progress
        default: return .today
        }
        #else
        return .today
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BGAmbientBackground()

            Group {
                switch tab {
                case .today:     TodayView()
                case .library:   LibraryView()
                case .takeaways: TakeawaysView()
                case .progress:  ProgressScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BGTabBar(selection: $tab)
        }
    }
}

/// The floating glass panel: radius 26, fill `.07`, border `.14`, blur 20, a soft top shadow.
/// Inactive icons ink .4, active brass. Today's icon is the bookmark motif.
///
/// No home indicator. The handoff's frames draw one as a `<div>` because a web mockup has no OS
/// chrome to borrow; on the phone iOS draws the real one, so copying the div gave the screen two —
/// a decoy 130×5 capsule sitting a centimetre above the genuine article. The 18pt of bottom
/// padding is what that capsule and its spacing used to occupy, so the panel has not moved.
struct BGTabBar: View {
    @Binding var selection: BGTab
    @Environment(\.bgPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BGTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 11)
        .padding(.horizontal, 20)
        .padding(.bottom, 5)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(palette.glassQuiet))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(palette.glassBorder, lineWidth: 1))
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // `0 -1px 16px rgba(0,0,0,.35)` on dark, `rgba(90,60,30,.2)` on light. Black was
        // hardcoded here for both, and on paper a black cast reads as grime, not depth.
        .shadow(color: palette.shadowColor.opacity(palette.isDark ? 0.35 : 0.20),
                radius: 16, x: 0, y: -1)
        .padding(.horizontal, 44)
        .padding(.bottom, 18)
    }

    private func tabButton(_ tab: BGTab) -> some View {
        let active = tab == selection
        // Both from the palette: this bar is themed, and the dark palette's cream at .4 over the
        // light bar's near-white material left Library, Takeaways and Progress invisible.
        let tint = active ? palette.brassLabel : palette.tabInactive
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Group {
                    if tab == .today {
                        BookmarkShape(notch: 0.74)
                            .fill(active ? palette.brassObject : LinearGradient(colors: [tint, tint], startPoint: .top, endPoint: .bottom))
                            .frame(width: 14, height: 19)
                    } else {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(tint)
                            .frame(height: 19)
                    }
                }
                Text(tab.title)
                    .font(BGFont.ui(9.5, .medium))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}
