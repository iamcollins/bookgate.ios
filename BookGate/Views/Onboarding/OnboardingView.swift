import SwiftUI
import UserNotifications

/// First-open onboarding — 7 steps, order normative: welcome → how it works → set your reading time
/// (time + length + nights, on the sundial) → add your book (skippable) → shielded apps →
/// permissions → trial. **Only the four setup steps carry the numbered dots** (alarm·add·apps·
/// permissions) so setup never feels long. The paywall goes last, so the trial starts against a real
/// book, time and app list.
struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    enum Step: Int, CaseIterable { case welcome, how, alarm, addBook, apps, permissions, paywall }
    @State private var step: Step

    /// `initialStep` is for the screenshot harness, which captures several steps in one process.
    init(initialStep: Step? = nil, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _step = State(initialValue: initialStep ?? Self.defaultStep)
    }

    private static var defaultStep: Step {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["BOOKGATE_ONB_STEP"], let i = Int(v),
           let s = Step(rawValue: i) { return s }
        #endif
        return .welcome
    }

    /// The minute the alarm step's sky is currently showing (driven by the step, including its load
    /// auto-rise) so the strip behind the page dots matches the sky's top colour at every moment.
    /// Starts at the bright 16:00 so the strip never flashes dark while transitioning into the step.
    @State private var alarmSkyMin = 960

    /// The four setup steps that carry dots.
    private static let dotted: [Step] = [.alarm, .addBook, .apps, .permissions]
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
            } else if step == .addBook {
                // Add-book carries the same sky, frozen at the chosen time.
                let mins = services.store.alarms.first(where: { $0.isOn })?.readingMin
                    ?? services.store.alarms.first?.readingMin ?? 1260
                ReadingSky.top(ReadingSky.nightness(mins)).ignoresSafeArea()
            } else {
                BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.18), showGlow: step != .welcome)
            }
            VStack(spacing: 0) {
                // Nav row: progress dots centred, with back (left) / skip (right) at the same level —
                // the standard top position, so they never sit low inside a step.
                ZStack {
                    if let dotIndex { PageDots(count: Self.dotted.count, index: dotIndex) }
                    if step == .addBook {
                        HStack {
                            Button(action: back) {
                                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(palette.ink(.secondary)).frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("Skip") { next() }
                                .font(BGFont.ui(15, .medium)).foregroundStyle(palette.ink(.secondary))
                                .frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                Group {
                    switch step {
                    case .welcome:     WelcomeStep(next: next, restore: restore)
                    case .how:         HowItWorksStep(next: next)
                    case .alarm:       AlarmSetupStep(next: next, skyMin: $alarmSkyMin)
                    case .addBook:     AddBookStep(next: next)
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

    private func back() {
        if let p = Step(rawValue: step.rawValue - 1) {
            if p == .alarm { alarmSkyMin = 960 }   // re-entering the sundial replays its rise
            step = p
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
