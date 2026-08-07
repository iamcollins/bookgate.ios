import SwiftUI
import UserNotifications

/// First-open onboarding — 8 steps, order normative: welcome → how it works → set your reading time
/// → add your book (skippable) → length → shielded apps → permissions → trial. **Only the five setup
/// steps carry the numbered dots** (alarm·add·length·apps·permissions) so setup never feels like
/// eight. The paywall goes last, so the trial starts against a real book, time and app list.
struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    enum Step: Int, CaseIterable { case welcome, how, alarm, addBook, length, apps, permissions, paywall }
    @State private var step: Step = {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["BOOKGATE_ONB_STEP"], let i = Int(v),
           let s = Step(rawValue: i) { return s }
        #endif
        return .welcome
    }()

    /// The minute the alarm step's sky is currently showing (driven by the step, including its load
    /// auto-rise) so the strip behind the page dots matches the sky's top colour at every moment.
    /// Starts at the bright 16:00 so the strip never flashes dark while transitioning into the step.
    @State private var alarmSkyMin = 960

    /// The five setup steps that carry dots.
    private static let dotted: [Step] = [.alarm, .addBook, .length, .apps, .permissions]
    private var dotIndex: Int? { Self.dotted.firstIndex(of: step) }

    /// Step crossfade duration. Entering the alarm step is **instant** — crossfading it would leave
    /// the previous screen's content fading over the half-faded (semi-transparent) sky, which reads as
    /// a dark strip at the top. Its own load auto-rise is the entrance instead.
    private var stepAnimDuration: Double {
        step == .alarm ? 0 : 0.35
    }

    var body: some View {
        ZStack {
            // The alarm step gets a full-bleed evening sky behind everything (dots included); welcome
            // carries its own single glow behind the book; every other step uses the drifting blobs.
            if step == .alarm {
                // The step draws the sky; here we only fill the strip above it (behind the dots) with
                // the sky's top colour so the two meet seamlessly. `alarmSkyMin` is driven by the step
                // (including its load auto-rise) so this strip tracks the sky at every moment.
                ReadingSky.top(ReadingSky.nightness(alarmSkyMin)).ignoresSafeArea()
            } else {
                BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.18), showGlow: step != .welcome)
            }
            VStack(spacing: 0) {
                if let dotIndex {
                    PageDots(count: Self.dotted.count, index: dotIndex).padding(.top, 60)
                }
                Group {
                    switch step {
                    case .welcome:     WelcomeStep(next: next, restore: restore)
                    case .how:         HowItWorksStep(next: next)
                    case .alarm:       AlarmSetupStep(next: next, skyMin: $alarmSkyMin)
                    case .addBook:     AddBookStep(next: next)
                    case .length:      LengthStep(next: next)
                    case .apps:        AppsStep(next: next)
                    case .permissions: PermissionsStep(next: next)
                    case .paywall:     PaywallView(onSubscribed: finish)
                    }
                }
                .environment(services)
                .frame(maxHeight: .infinity)
                // Crossfade only the step *content*, not the background — so the background swaps
                // instantly to the (bright) alarm sky and the top strip never flashes dark.
                .animation(.easeInOut(duration: stepAnimDuration), value: step)
            }
        }
        .nightFlow()   // onboarding shows the dark brand surface regardless of system theme
    }

    private func next() {
        if let n = Step(rawValue: step.rawValue + 1) {
            // Reset the alarm strip to the bright 16:00 start *before* the crossfade, so entering the
            // alarm step never shows a dark top strip.
            if n == .alarm { alarmSkyMin = 960 }
            step = n
        }
    }
    private func restore() {
        Task { if await services.subscription.restore() == .restored { finish() } }
    }
    private func finish() {
        // Ensure a reading alarm exists (default 9pm nightly) so Today + scheduling work.
        if services.store.alarms.isEmpty { services.store.add() }
        Task { await services.resync() }
        onComplete()
    }
}

/// Four-step progress dots, active dot brass.
struct PageDots: View {
    let count: Int
    let index: Int
    @Environment(\.bgPalette) private var palette
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(palette.ink(.disabled)))
                    .frame(width: i == index ? 20 : 7, height: 7)
            }
        }
    }
}
