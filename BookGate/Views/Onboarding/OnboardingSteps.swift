import SwiftUI
import UserNotifications

// MARK: 1 — Welcome (8a)

struct WelcomeStep: View {
    var next: () -> Void
    var restore: () -> Void
    @Environment(\.bgPalette) private var palette
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 88)
            BookMark().background { markGlow }
            Spacer().frame(height: 44)
            Text("BOOKGATE")
                .font(.caption2).fontWeight(.semibold).tracking(2.4)
                .foregroundStyle(Color(hex: 0xE9B872))
            Text("Make reading\nhappen.")
                .font(BGFont.serifDynamic(36, .medium, relativeTo: .largeTitle))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
            Text("An alarm for your book, and a camera that makes sure you actually start.")
                .font(BGFont.serifItalicDynamic(16.5, .regular, relativeTo: .callout))
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.6))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16).padding(.horizontal, 4)
            Spacer()
            Button("Get Started") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 58))
            Button { restore() } label: {
                HStack(spacing: 4) {
                    Text("Already subscribed?").foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.6))
                    Text("Restore").foregroundStyle(palette.brassValue)
                }
                .font(.footnote).fontWeight(.medium)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 28).padding(.bottom, 40)
    }

    /// The warm glow that sits directly behind the book (radial, blurred, breathing) — the "power".
    private var markGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xF0BE78, opacity: 0.34), .clear],
                                 center: .center, startRadius: 0, endRadius: 380 * 0.31))
            .frame(width: 380, height: 380)
            .blur(radius: 36)
            .allowsHitTesting(false)
    }
}

/// The welcome mark (design 8a): a cream book — the contrast object on the dark base — with the
/// brass bookmark ribbon draped over it, a spine, page lines, and a lift shadow. It floats.
struct BookMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false

    var body: some View {
        ZStack {
            // lift shadow ellipse
            Ellipse().fill(Color.black.opacity(0.5)).frame(width: 104, height: 18).blur(radius: 10)
                .offset(y: 66 + 14)
            // book body
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE9DCC6), Color(hex: 0xCDBC9F), Color(hex: 0xB8A687)],
                                     startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1)))
                .frame(width: 132, height: 132)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1).blendMode(.plusLighter))
                .shadow(color: .black.opacity(0.75), radius: 20, x: 0, y: 18)
            // spine + page lines, positioned within the 132×132 book
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: 132, height: 132)
                Rectangle().fill(Color(hex: 0x5A4228, opacity: 0.35)).frame(width: 2, height: 132).offset(x: 16)
                pageLine(top: 34, leadingInset: 46, trailingInset: 22, opacity: 0.22)
                pageLine(top: 48, leadingInset: 46, trailingInset: 30, opacity: 0.18)
                pageLine(top: 62, leadingInset: 46, trailingInset: 40, opacity: 0.14)
            }
            .frame(width: 132, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            // brass ribbon draped over the top, right of centre, poking 8px above
            BookmarkShape(notch: 0.76)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hex: 0xF2CB95), location: 0),
                    .init(color: Color(hex: 0xD79A56), location: 0.70),
                    .init(color: Color(hex: 0xC0863F), location: 1.0),
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 74)
                .shadow(color: .black.opacity(0.5), radius: 9, x: 0, y: 8)
                .offset(x: 132/2 - 28 - 13, y: -132/2 - 8 + 37)
        }
        .frame(width: 132, height: 132)
        .offset(y: reduceMotion ? 0 : (float ? -9 : 5))
        .animation(reduceMotion ? nil : .easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: float)
        .onAppear { float = true }
    }

    private func pageLine(top: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat, opacity: Double) -> some View {
        Rectangle()
            .fill(Color(hex: 0x5A4228, opacity: opacity))
            .frame(width: 132 - leadingInset - trailingInset, height: 3)
            .cornerRadius(2)
            .offset(x: leadingInset, y: top)
    }
}

// MARK: 2 — How it works (8b)

struct HowItWorksStep: View {
    var next: () -> Void
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let steps: [(num: String, symbol: String, filled: Bool, title: String, sub: String)] = [
        ("01", "clock", false, "Your reading alarm", "Set the hour once — it finds you every night."),
        ("02", "camera", false, "You and your book", "A photo of you both starts the session."),
        ("03", "shield", false, "The noise waits", "Chosen apps stay shut until you finish."),
        ("04", "waveform", false, "Record a takeaway", "A few words in your own voice, kept with the book."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // TOP — title + subtitle
            VStack(alignment: .leading, spacing: 12) {
                Text("A few minutes,\nevery night.")
                    .font(BGFont.serifDynamic(36, .medium, relativeTo: .largeTitle))
                    .foregroundStyle(palette.ink(.hero))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Build the reading habit you keep meaning to start.")
                    .font(BGFont.serifItalicDynamic(16.5, .regular, relativeTo: .callout))
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.6))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MIDDLE — steps evenly distributed; connector drawn as separate gap-only segments.
            GeometryReader { geo in
                let n = steps.count
                let rowH = geo.size.height / CGFloat(n)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<(n - 1), id: \.self) { i in
                        let gapTop = rowH * (CGFloat(i) + 0.5) + 26      // bottom edge of circle i
                        let gapBottom = rowH * (CGFloat(i) + 1.5) - 26   // top edge of circle i+1
                        Rectangle().fill(Color(hex: 0xE9B872, opacity: 0.3))
                            .frame(width: 1, height: max(0, gapBottom - gapTop))
                            .position(x: 26, y: (gapTop + gapBottom) / 2)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            timelineRow(step, index: i).frame(height: rowH)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Spacer().frame(height: 24)   // breathing room under the last step

            // BOTTOM — button
            Button("Set it up") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 40)
    }

    private func timelineRow(_ step: (num: String, symbol: String, filled: Bool, title: String, sub: String),
                             index: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            node(step.symbol, filled: step.filled, index: index).frame(width: 52)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(step.num).font(.caption2).fontWeight(.semibold).tracking(1)
                        .foregroundStyle(palette.brassValue)
                    Rectangle().fill(Color(hex: 0xE9B872, opacity: 0.4)).frame(width: 22, height: 1)
                }
                Text(step.title)
                    .font(BGFont.serifDynamic(25, .medium, relativeTo: .title2))
                    .foregroundStyle(palette.ink(.hero))
                Text(step.sub)
                    .font(.callout).foregroundStyle(palette.ink(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 52pt circular node with a brass icon (filled variant for the shield). The icons breathe
    /// **one at a time** — each does two breaths (scale + a subtle brass glow), then the next takes
    /// over, looping forever down the timeline. Frozen under Reduce Motion.
    private func node(_ symbol: String, filled: Bool, index: Int) -> some View {
        let rm = reduceMotion   // capture locally so the @Sendable keyframe closures don't touch the actor
        return Circle()
            .fill(Color(hex: 0xE9B872, opacity: filled ? 0.16 : 0.0))
            .overlay(Circle().strokeBorder(Color(hex: 0xE9B872, opacity: 0.35), lineWidth: 1.5))
            .frame(width: 52, height: 52)
            .overlay {
                // glow behind the icon, brightening on each breath
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF0C68F), .clear],
                                         center: .center, startRadius: 0, endRadius: 34))
                    .frame(width: 66, height: 66).blur(radius: 9)
                    .keyframeAnimator(initialValue: 0.0, repeating: !rm) { view, p in
                        view.opacity(rm ? 0 : 0.55 * p).scaleEffect(0.8 + 0.4 * p)
                    } keyframes: { _ in breathCycle(index: index) }
            }
            .overlay {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Color(hex: 0xE9B872))
                    .keyframeAnimator(initialValue: 0.0, repeating: !rm) { view, p in
                        view.scaleEffect(rm ? 1 : 1 + 0.10 * p)
                    } keyframes: { _ in breathCycle(index: index) }
            }
    }

    /// One full loop cycle for a node: wait for its turn, breathe **twice** (slow), then wait while
    /// the others go — every node's cycle is the same length, so `repeating` keeps them in sequence.
    @KeyframesBuilder<Double>
    private func breathCycle(index: Int) -> some Keyframes<Double> {
        let half = 1.6                     // slow breath: 1.6s per half (~3.2s per breath)
        let slot = 2.0 * (2 * half)        // two breaths per turn
        KeyframeTrack(\.self) {
            LinearKeyframe(0.0, duration: Double(index) * slot + 0.0001)            // wait for turn
            CubicKeyframe(1.0, duration: half); CubicKeyframe(0.0, duration: half)  // breath 1
            CubicKeyframe(1.0, duration: half); CubicKeyframe(0.0, duration: half)  // breath 2
            LinearKeyframe(0.0, duration: Double(steps.count - 1 - index) * slot + 0.0001) // wait for others
        }
    }
}

// MARK: 4 — Your first book (8c). Carries the same evening sky as the reading-time step (frozen at the
// hour they picked), recaps the schedule they just set, then asks for the book. Barcode is the design's
// fast path, but BookGate is on-device with no barcode/ISBN/network, so "Photograph the cover" leads.

struct AddBookStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title = ""
    @State private var coverJPEG: Data?
    @State private var coverImage: UIImage?
    @State private var showCapture = false
    @State private var float = false      // perpetual gentle bob
    @State private var breathe = false    // the glow, breathing like a lamp
    @State private var appeared = false   // one-time entrance bloom
    /// The reading alarm just set, captured on appear (so the recap matches the previous screen).
    @State private var schedule: Schedule?

    var body: some View {
        Group {
            if let schedule { content(schedule) } else { Color.clear }
        }
        .onAppear {
            if schedule == nil { schedule = services.store.alarms.first ?? services.store.primary }
            float = true
            breathe = true
            withAnimation(.easeOut(duration: 0.65)) { appeared = true }
        }
    }

    private func content(_ s: Schedule) -> some View {
        ZStack {
            // The same evening, moon set aside — the book is the light now.
            ReadingSkyStage(minute: Double(s.readingMin == 0 ? 1440 : s.readingMin), showMoon: false)
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Would you like to add\nyour first book?")
                        .font(BGFont.serifDynamic(29, .medium, relativeTo: .title))
                        .foregroundStyle(palette.ink(.hero))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(recap(s))
                        .font(BGFont.serifItalicDynamic(15, .regular, relativeTo: .callout))
                        .foregroundStyle(palette.brassValue)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 6)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)

                Spacer(minLength: 12)

                Button { showCapture = true } label: { bookHero }.buttonStyle(.plain)

                Text(coverImage == nil ? "Tap to photograph the cover" : "Looks good — tap to retake")
                    .font(BGFont.aside(13.5)).foregroundStyle(palette.ink(.secondary))
                    .padding(.top, 22)

                Spacer(minLength: 12)

                TextField("", text: $title,
                          prompt: Text("or type the title").foregroundStyle(palette.ink(.disabled)))
                    .font(BGFont.row).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
                    .padding(14).frame(maxWidth: 300).glass(.quiet, cornerRadius: 16)

                Spacer().frame(height: 20)
                Button("Continue") { addIfNeeded(); next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 34)
        }
        .fullScreenCover(isPresented: $showCapture) {
            CoverCaptureView { jpeg, image, ocr in
                coverJPEG = jpeg; coverImage = image
                if title.isEmpty, let ocr, !ocr.isEmpty { title = ocr }
            }
        }
    }

    /// A cream book (or the photographed cover) with the brass bookmark ribbon, floating over a warm
    /// glow — the welcome mark, now the tap target for adding the book.
    private var bookHero: some View {
        let w: CGFloat = 152, h: CGFloat = 224
        return ZStack {
            // The lamp: a warm glow behind the book, breathing slowly.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xF0BE78, opacity: 0.34), .clear],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 330, height: 330).blur(radius: 44)
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.08 : 0.94))
                .opacity(reduceMotion ? 0.32 : (breathe ? 0.44 : 0.24))
                .animation(reduceMotion ? nil : .easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: breathe)
                .allowsHitTesting(false)
            Ellipse().fill(Color.black.opacity(0.5)).frame(width: w * 0.78, height: 20)
                .blur(radius: 12).offset(y: h / 2 + 22)

            Group {
                if let coverImage {
                    Image(uiImage: coverImage).resizable().scaledToFill().frame(width: w, height: h).clipped()
                } else {
                    ZStack {
                        LinearGradient(colors: [Color(hex: 0xE9DCC6), Color(hex: 0xCDBC9F), Color(hex: 0xB8A687)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Rectangle().fill(Color(hex: 0x5A4228, opacity: 0.32)).frame(width: 2)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
                        Image(systemName: "camera.fill").font(.system(size: 25, weight: .light))
                            .foregroundStyle(Color(hex: 0x5A4228, opacity: reduceMotion ? 0.5 : (breathe ? 0.6 : 0.38)))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: breathe)
                    }
                    .frame(width: w, height: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1).blendMode(.plusLighter))
            .shadow(color: .black.opacity(0.6), radius: 22, x: 0, y: 16)

            BookmarkShape(notch: 0.76)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hex: 0xF2CB95), location: 0),
                    .init(color: Color(hex: 0xD79A56), location: 0.70),
                    .init(color: Color(hex: 0xC0863F), location: 1.0),
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 80)
                .shadow(color: .black.opacity(0.5), radius: 9, x: 0, y: 8)
                .offset(x: w / 2 - 30, y: -h / 2 - 8 + 40)
        }
        .frame(width: w, height: h)
        // Perpetual gentle bob.
        .offset(y: reduceMotion ? 0 : (float ? -8 : 4))
        .animation(reduceMotion ? nil : .easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: float)
        // One-time entrance: the book blooms into the light.
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
    }

    /// "Every night at 9:00 PM, for 5 minutes." — the schedule just set, in words.
    private func recap(_ s: Schedule) -> String {
        let len = services.settings.defaultLength
        let lenPhrase = len == 60 ? String(localized: "1 hour") : String(localized: "\(len) minutes")
        return String(localized: "\(s.dayLabel) at \(s.timeLabel), for \(lenPhrase).")
    }

    private func addIfNeeded() {
        let t = title.trimmingCharacters(in: .whitespaces)
        // A photographed cover is enough to add the book: OCR often reads the author or a strapline
        // rather than the title, and silently discarding someone's photo because the title box was
        // empty lost the whole step's work. The cover is the book's identity until it's renamed.
        guard !t.isEmpty || coverJPEG != nil else { return }
        let name = t.isEmpty ? String(localized: "My book") : t
        let book = services.books.add(title: name, status: .reading)
        if let coverJPEG { services.books.setCover(coverJPEG, for: book) }
    }
}

// MARK: 5 — Shielded apps (8d)

struct AppsStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var showPicker = false

    private var alarmTime: String { services.store.schedule(for: nil)?.timeLabel ?? "9:00 PM" }

    var body: some View {
        @Bindable var shield = services.shield
        return VStack(spacing: 16) {
            Spacer().frame(height: 6)
            Text("Which apps usually win at \(alarmTime)?")
                .font(BGFont.serifDynamic(27, .medium, relativeTo: .title))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("They'll be held back while you read. Nothing is deleted, nothing is reported.")
                .font(BGFont.serifItalicDynamic(15, .regular, relativeTo: .callout))
                .foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("By category").sectionLabel()
                categoryRow("Social", "square.grid.2x2.fill")
                categoryRow("Video", "play.rectangle.fill")
                categoryRow("Games", "gamecontroller.fill")
                Text("Or pick apps").sectionLabel().padding(.top, 6)
                Button { showPicker = true } label: {
                    HStack {
                        Text(services.shield.shieldedCount > 0 ? "\(services.shield.shieldedCount) chosen" : "Choose individual apps")
                            .font(BGFont.row).foregroundStyle(palette.ink(.strong))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.ink(.secondary))
                    }
                    .padding(14).frame(maxWidth: .infinity).glass(.quiet, cornerRadius: 16).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }

            Spacer()
            Button("Shield these while I read") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
        .shieldPicker(isPresented: $showPicker, shield: shield)
    }

    private func categoryRow(_ name: String, _ symbol: String) -> some View {
        Button { showPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(palette.brassValue).frame(width: 26)
                Text(name).font(BGFont.row).foregroundStyle(palette.ink(.strong))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.ink(.secondary))
            }
            .padding(14).frame(maxWidth: .infinity).glass(.card, cornerRadius: 16).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: 6 — Permissions (8e), granted one at a time

struct PermissionsStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var alarmGranted = false
    @State private var camGranted = false
    @State private var screenTimeGranted = false
    @State private var micGranted = false

    private var alarmTime: String { services.store.schedule(for: nil)?.timeLabel ?? "9:00 PM" }

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 6)
            Text("Four permissions, four reasons.")
                .font(BGFont.serifDynamic(27, .medium, relativeTo: .title))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 11) {
                permRow("alarm.fill", "Alarms", "So \(alarmTime) actually reaches you, even on silent.", nil, alarmGranted) {
                    Task { alarmGranted = await services.scheduler.requestAuthorization() }
                }
                // Deliberate deviation from the design's "Nothing is saved or sent": the nightly
                // journal photo IS saved on-device, so consent is stated truthfully.
                permRow("camera.fill", "Camera", "To see you and your book. Photos stay on your phone.", nil, camGranted) {
                    Task { camGranted = (await CameraAccess.request()) == .authorized }
                }
                permRow("hourglass", "App shielding", "Screen Time holds your picks back mid-session.", nil, screenTimeGranted) {
                    Task { screenTimeGranted = await services.shield.requestAuthorization() }
                }
                permRow("mic.fill", "Microphone", "Only for takeaways. Recordings stay on your phone.", "OPTIONAL", micGranted) {
                    Task { micGranted = await AudioRecorder.requestPermission() }
                }
            }
            Spacer()
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }

    private func permRow(_ symbol: String, _ title: String, _ why: String, _ tag: String?, _ granted: Bool, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(palette.brassValue).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(BGFont.ui(15, .semibold)).foregroundStyle(palette.ink(.hero))
                    if let tag {
                        Text(tag).font(BGFont.ui(8.5, .bold)).tracking(0.5).foregroundStyle(palette.ink(.caption))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
                    }
                }
                Text(why).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(palette.brassValue)
            } else {
                Button("Allow", action: action).font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                    .padding(.horizontal, 12).padding(.vertical, 7).glass(.quiet, cornerRadius: 13)
            }
        }
        .padding(14).frame(maxWidth: .infinity).glass(.card, cornerRadius: 18)
    }
}
