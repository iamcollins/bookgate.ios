import SwiftUI
import UIKit

/// Holds the screen awake for as long as the view is on screen.
///
/// Every part of the night flow is something the user *looks at while doing something else with
/// their hands* — holding a book up to the camera, or reading a paper book with the phone resting
/// beside them. The default idle timer blanks the screen after a couple of minutes, which killed
/// the camera gate mid-scan and put out the session lamp (whose whole job is to still be there,
/// dimmer, when you glance over). So the night flow asks the system to stay awake, and gives that
/// back the moment it ends.
///
/// Reference-counted: nested users (the night flow *and* a camera screen inside it) each hold a
/// claim, and the timer is only re-enabled when the last one goes away.
@MainActor
private final class WakeLock {
    static let shared = WakeLock()
    private var count = 0

    func acquire() {
        count += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func release() {
        count = max(0, count - 1)
        if count == 0 { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

private struct KeepAwakeModifier: ViewModifier {
    let active: Bool
    @State private var held = false

    func body(content: Content) -> some View {
        content
            .onAppear { sync(active) }
            .onChange(of: active) { _, now in sync(now) }
            .onDisappear { sync(false) }
    }

    private func sync(_ want: Bool) {
        guard want != held else { return }
        held = want
        want ? WakeLock.shared.acquire() : WakeLock.shared.release()
    }
}

extension View {
    /// Keep the screen lit while this view is visible (and `active`).
    func keepAwake(_ active: Bool = true) -> some View {
        modifier(KeepAwakeModifier(active: active))
    }
}
