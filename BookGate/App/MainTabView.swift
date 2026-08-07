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
    @State private var tab: BGTab = {
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
    }()

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

/// The floating glass panel: radius 26, fill `.07`, border `.14`, blur 20, a soft top shadow, and a
/// home indicator below it. Inactive icons ink .4, active brass. Today's icon is the bookmark motif.
struct BGTabBar: View {
    @Binding var selection: BGTab
    @Environment(\.bgPalette) private var palette

    var body: some View {
        VStack(spacing: 9) {
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
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: -1)
            .padding(.horizontal, 44)

            // Home indicator.
            Capsule()
                .fill(Color(hex: 0xF7EFE4, opacity: 0.28))
                .frame(width: 130, height: 5)
        }
        .padding(.bottom, 4)
    }

    private func tabButton(_ tab: BGTab) -> some View {
        let active = tab == selection
        let tint = active ? palette.brassLabel : Color(hex: 0xF7EFE4, opacity: 0.4)
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
