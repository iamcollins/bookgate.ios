import SwiftUI
import SubscriptionKitUI

/// Top surface. Gates onboarding, hosts the tab shell, overlays the night flow (always dark) and
/// the hard paywall, applies the theme, and drives the app lifecycle.
struct RootView: View {
    @Bindable var services: AppServices
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("bookgate.onboarding.v1.done") private var onboarded = false

    var body: some View {
        Group {
            if !onboarded {
                OnboardingView(onComplete: { onboarded = true })
                    .environment(services)
            } else {
                mainShell
            }
        }
        .task { await services.onLaunch() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await services.onForeground() } }
        }
    }

    private var mainShell: some View {
        ZStack {
            // Hard paywall: laid over Today when the trial has lapsed / no entitlement — but never
            // while an alarm rings or a session runs, and with no way to dismiss. `subscriptionWall`
            // (SubscriptionKit) owns the rule that a still-`unknown` entitlement is NOT walled, so a
            // paying subscriber never meets the wall on a slow launch.
            MainTabView()
                .themedRoot(services.settings.theme)
                .subscriptionWall(store: services.subscription,
                                  suppressedWhile: services.session.phase != .idle) {
                    PaywallView(onSubscribed: {})
                        .transition(.opacity)
                }

            // The night flow takes over the whole screen (always dark) whenever it is running.
            if services.session.phase != .idle {
                NightFlowView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .environment(services)
        .animation(.easeInOut(duration: 0.4), value: services.session.phase)
        .animation(.easeInOut(duration: 0.3), value: services.subscription.entitlement)
    }
}
