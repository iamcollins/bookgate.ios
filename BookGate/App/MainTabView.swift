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

/// The four-tab shell on the **system tab bar**.
///
/// This was a hand-built `HStack` in a `ZStack` for a long time, because the handoff draws the bar
/// as a floating rounded panel and a web mockup cannot show OS chrome. iOS 26's own tab bar *is*
/// that floating panel — Liquid Glass, its own shadow, and a selection bubble that morphs between
/// tabs — so the custom one was reproducing, badly, a component the platform ships. Everything it
/// used to hand-draw (material, bubble, shadow, the inactive/active tints, the accessibility
/// traits, minimising as content scrolls) now comes from `TabView`.
///
/// The ambient wash rides behind Today only; Library, Takeaways and Progress each draw their own.
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
        TabView(selection: $tab) {
            Tab(BGTab.today.title, systemImage: BGTab.today.symbol, value: BGTab.today) {
                ZStack {
                    BGAmbientBackground()
                    TodayView(onOpenLibrary: { tab = .library })
                }
            }
            Tab(BGTab.library.title, systemImage: BGTab.library.symbol, value: BGTab.library) {
                LibraryView()
            }
            Tab(BGTab.takeaways.title, systemImage: BGTab.takeaways.symbol, value: BGTab.takeaways) {
                TakeawaysView()
            }
            Tab(BGTab.progress.title, systemImage: BGTab.progress.symbol, value: BGTab.progress) {
                ProgressScreen()
            }
        }
        // The one thing the bar still takes from the palette: brass marks the selected tab.
        .tint(palette.brassLabel)
    }
}
