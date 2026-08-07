import SwiftUI

/// User's theme choice. `system` follows the OS; the night flow ignores all of these.
enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light:  return String(localized: "Light")
        case .dark:   return String(localized: "Dark")
        }
    }
}

private struct BGPaletteKey: EnvironmentKey {
    static let defaultValue: BGPalette = .dark
}

extension EnvironmentValues {
    /// The resolved surface palette for the current context. Read this in every view instead of
    /// hard-coding colours, so a single value drives dark ↔ light.
    var bgPalette: BGPalette {
        get { self[BGPaletteKey.self] }
        set { self[BGPaletteKey.self] = newValue }
    }
}

extension View {
    /// Resolve `preference` against the live system appearance and inject the matching palette,
    /// also pinning the SwiftUI colour scheme so system chrome (keyboards, menus) matches.
    /// Apply once, high in the app-shell hierarchy.
    func themedRoot(_ preference: ThemePreference) -> some View {
        modifier(ThemedRoot(preference: preference))
    }

    /// Force the dark palette regardless of theme — for the night flow (alarm → camera → session →
    /// shield → complete). Also pins `.preferredColorScheme(.dark)` for any nested system chrome.
    func nightFlow() -> some View {
        environment(\.bgPalette, .dark)
            .preferredColorScheme(.dark)
    }
}

private struct ThemedRoot: ViewModifier {
    let preference: ThemePreference
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedIsDark: Bool {
        switch preference {
        case .system: return systemScheme == .dark
        case .light:  return false
        case .dark:   return true
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.bgPalette, resolvedIsDark ? .dark : .light)
            .preferredColorScheme(preference == .system ? nil : (resolvedIsDark ? .dark : .light))
    }
}
