import SwiftUI

// MARK: 3 — Set your reading time (the sundial)

/// The onboarding "wow" step, keeping the promise the How-it-works timeline makes ("Set your
/// reading time"). Swipe **up** on the sky and the hour gets later — the moon rises, dusk deepens
/// into espresso night. Minutes are set on a brass **sundial ring** (a bookmark bead on a shallow
/// arc). Both write the single reading alarm's `readingMin`; the day pills set its active nights.
struct AlarmSetupStep: View {
    var next: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    /// The single reading alarm, captured on appear so `body` never mutates the store to create it.
    @State private var schedule: Schedule?

    // Scrub state (Thrise's onboarding pattern): a fixed pixel→minute ratio with a top/bottom
    // dead-zone so a drag near the dots or the control bar doesn't scrub.
    @State private var scrubStart: Int?
    @State private var scrubIgnored = false
    /// Swipe sensitivity: fewer points per minute = the moon/time move faster under the finger.
    private static let pxPerMinute: CGFloat = 1.05
    /// The allowed window: 16:00 → 00:00 (midnight stored as readingMin 0).
    private static let windowStart = 960     // 16:00
    private static let windowEnd = 1440      // 00:00 next day

    var body: some View {
        Group {
            if let schedule {
                content(schedule)
            } else {
                Color.clear
            }
        }
        .onAppear { if schedule == nil { schedule = services.store.primary } }
    }

    private func content(_ s: Schedule) -> some View {
        // The sky lives here (so its geometry — and the moon's travel — is the step's own height).
        // OnboardingView fills the strip above this slot with the sky's top colour so there's no seam.
        GeometryReader { geo in
            ZStack {
                ReadingSkyStage(readingMin: s.readingMin)
                VStack(spacing: 0) {
                    titleBlock(s)
                    Spacer(minLength: 0)
                    heroReadout(s)
                    Spacer(minLength: 0).frame(maxHeight: 96)
                    controlBar(s)
                }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .contentShape(Rectangle())
            .gesture(scrub(s, height: geo.size.height))
        }
        .sensoryFeedback(.selection, trigger: s.readingMin)
    }

    // MARK: Pieces

    private func titleBlock(_ s: Schedule) -> some View {
        let line = contextLine(s.readingMin)
        return VStack(spacing: 10) {
            Text("When do you read?")
                .font(BGFont.serifDynamic(30, .medium, relativeTo: .title))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            // The evocative line that changes with the hour now lives here (replacing the old
            // "Swipe up…" hint), so it reads as a subtitle to the question.
            Text(line)
                .font(BGFont.serifItalicDynamic(16, .regular, relativeTo: .callout))
                .foregroundStyle(palette.brassValue)
                .multilineTextAlignment(.center)
                // A tight dark halo so the line stays legible when the risen moon sits behind it.
                .shadow(color: .black.opacity(0.6), radius: 4)
                .shadow(color: .black.opacity(0.4), radius: 9)
                .id(line)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: line)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
    }

    private func heroReadout(_ s: Schedule) -> some View {
        let parts = Schedule.hourMinute(s.readingMin)
        let len = services.settings.defaultLength
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(parts.time)
                    .font(BGFont.numeralHero)
                    .foregroundStyle(palette.ink(.hero))
                    .contentTransition(.numericText(value: Double(s.readingMin)))
                if !parts.marker.isEmpty {
                    Text(parts.marker)
                        .font(BGFont.serif(23, .medium))
                        .foregroundStyle(palette.ink(.secondary))
                }
            }
            .animation(.snappy(duration: 0.3), value: s.readingMin)

            // The reading length, set on the ring below, shown prominently under the time.
            Text(lengthLabel(len))
                .font(BGFont.serifDynamic(18, .medium, relativeTo: .title3))
                .foregroundStyle(palette.brassValue)
                .contentTransition(.numericText(value: Double(len)))
                .animation(.snappy(duration: 0.25), value: len)
        }
        .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
    }

    private func lengthLabel(_ len: Int) -> String {
        len == 60 ? String(localized: "Read for 1 hour") : String(localized: "Read for \(len) min")
    }

    private func controlBar(_ s: Schedule) -> some View {
        VStack(spacing: 0) {
            SundialRing(length: lengthBinding, options: ReadingSettings.lengthOptions)
            Spacer().frame(height: 34)      // breathing room above the nights (keeps them apart)
            dayPills(s)
            Spacer().frame(height: 20)
            Button("Continue") {
                Task { await services.resync() }
                next()
            }
            .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
    }

    private func dayPills(_ s: Schedule) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = s.days[i]
                Button {
                    var d = s.days; d[i].toggle(); s.days = d
                } label: {
                    Text(Schedule.dayLetters[i])
                        .font(BGFont.ui(13, .semibold))
                        .foregroundStyle(on ? palette.actionText : palette.ink(.strong))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(on ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(palette.glassQuiet))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(on ? Color.clear : palette.hairline, lineWidth: 1)))
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Gesture

    private func scrub(_ s: Schedule, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if scrubStart == nil {
                    // Reserve the top (dots + title) and the bottom control band.
                    scrubIgnored = value.startLocation.y < 120 || value.startLocation.y > height - 240
                    scrubStart = scrubMinutes(s.readingMin)
                }
                guard !scrubIgnored, let start = scrubStart else { return }
                // Up = later. Clamp to the 16:00→00:00 window (no 24h wrap); midnight stores as 0.
                let delta = Int((-value.translation.height / Self.pxPerMinute).rounded())
                let raw = min(max(start + delta, Self.windowStart), Self.windowEnd)
                let snappedScrub = min(max(Int((Double(raw) / 5).rounded()) * 5, Self.windowStart), Self.windowEnd)
                let newReading = snappedScrub == Self.windowEnd ? 0 : snappedScrub
                if newReading != s.readingMin {
                    withAnimation(.easeOut(duration: 0.16)) { s.readingMin = newReading }
                }
            }
            .onEnded { _ in scrubStart = nil; scrubIgnored = false }
    }

    /// The scrub position (16:00→00:00, in minutes) for a stored reading time; midnight (0) → 1440.
    private func scrubMinutes(_ readingMin: Int) -> Int {
        readingMin == 0 ? Self.windowEnd : min(max(readingMin, Self.windowStart), Self.windowEnd)
    }

    // MARK: Bindings & copy

    /// The reading session length (app-wide "one length"), set on the sundial ring. Independent of
    /// the alarm time, so the ring never moves while you swipe the hour.
    private var lengthBinding: Binding<Int> {
        Binding(get: { services.settings.defaultLength },
                set: { services.settings.defaultLength = $0 })
    }

    /// The contextual line (now the subtitle) — reading-context copy across the 16:00→00:00 window.
    /// Midnight is stored as 0, so treat it as the late end.
    private func contextLine(_ m: Int) -> String {
        switch (m == 0 ? 1440 : m) {
        case ..<1110: return String(localized: "An early, unhurried read.")     // 16:00–18:30
        case ..<1200: return String(localized: "Golden-hour pages.")            // –20:00
        case ..<1290: return String(localized: "Prime wind-down hour.")         // –21:30
        case ..<1380: return String(localized: "The house goes quiet.")         // –23:00
        default:      return String(localized: "A late, lamplit page.")         // 23:00–00:00
        }
    }
}

// MARK: - Sundial ring (session length)

/// A shallow brass arc carrying a bookmark bead — the reading-length dial. One evenly-spaced stop per
/// offered duration (5 min … 1 hour); drag the bead to choose how long you read. Independent of the
/// alarm time, so it stays put while you swipe the hour above.
private struct SundialRing: View {
    @Binding var length: Int
    let options: [Int]
    @Environment(\.bgPalette) private var palette

    private let inset: CGFloat = 26
    private let arcDepth: CGFloat = 13

    private var activeIndex: Int { options.firstIndex(of: length) ?? 0 }

    var body: some View {
        // Just the arc + bead now — the value ("Read for X min") is shown up under the time.
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(options.indices, id: \.self) { i in
                    let isActive = i == activeIndex
                    Circle()
                        .fill(isActive ? AnyShapeStyle(palette.brassValue)
                                       : AnyShapeStyle(palette.ink(.disabled)))
                        .frame(width: isActive ? 5 : 3.5, height: isActive ? 5 : 3.5)
                        .position(point(frac(i), w, h))
                }
                Bookmark(width: 16, notch: 0.72)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                    .position(point(frac(activeIndex), w, h))
                    .animation(.snappy(duration: 0.22), value: length)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f = max(0, min(1, (value.location.x - inset) / (w - inset * 2)))
                        let idx = min(max(Int((f * CGFloat(options.count - 1)).rounded()), 0),
                                      options.count - 1)
                        if options[idx] != length { length = options[idx] }
                    }
            )
        }
        .frame(height: 36)
        .sensoryFeedback(.selection, trigger: length)
    }

    private func frac(_ i: Int) -> CGFloat {
        options.count <= 1 ? 0 : CGFloat(i) / CGFloat(options.count - 1)
    }

    /// Position along the shallow "smile" arc for a fraction `f` in 0…1.
    private func point(_ f: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let x = inset + f * (w - inset * 2)
        let y = (h - 8) - sin(f * .pi) * arcDepth   // lifts in the middle, mirroring the sky's arc
        return CGPoint(x: x, y: y)
    }
}
