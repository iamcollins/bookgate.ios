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

    /// The five setup steps that carry dots.
    private static let dotted: [Step] = [.alarm, .addBook, .length, .apps, .permissions]
    private var dotIndex: Int? { Self.dotted.firstIndex(of: step) }

    var body: some View {
        ZStack {
            // The alarm step gets a full-bleed evening sky behind everything (dots included); welcome
            // carries its own single glow behind the book; every other step uses the drifting blobs.
            if step == .alarm {
                // The step draws the sky; here we only fill the strip above it (behind the dots) with
                // the sky's top colour so the two meet seamlessly. Read the time without creating the
                // alarm (the step creates/owns it) to avoid mutating the store during layout.
                let mins = services.store.alarms.first(where: { $0.isOn })?.readingMin
                    ?? services.store.alarms.first?.readingMin ?? 1260
                ReadingSky.top(ReadingSky.nightness(mins)).ignoresSafeArea()
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
                    case .alarm:       AlarmSetupStep(next: next)
                    case .addBook:     AddBookStep(next: next)
                    case .length:      LengthStep(next: next)
                    case .apps:        AppsStep(next: next)
                    case .permissions: PermissionsStep(next: next)
                    case .paywall:     PaywallView(onSubscribed: finish)
                    }
                }
                .environment(services)
                .frame(maxHeight: .infinity)
            }
        }
        .nightFlow()   // onboarding shows the dark brand surface regardless of system theme
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func next() {
        if let n = Step(rawValue: step.rawValue + 1) { step = n }
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
