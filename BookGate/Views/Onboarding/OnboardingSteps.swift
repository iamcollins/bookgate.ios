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
        Circle()
            .fill(Color(hex: 0xE9B872, opacity: filled ? 0.16 : 0.0))
            .overlay(Circle().strokeBorder(Color(hex: 0xE9B872, opacity: 0.35), lineWidth: 1.5))
            .frame(width: 52, height: 52)
            .overlay {
                // glow behind the icon, brightening on each breath
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF0C68F), .clear],
                                         center: .center, startRadius: 0, endRadius: 34))
                    .frame(width: 66, height: 66).blur(radius: 9)
                    .keyframeAnimator(initialValue: 0.0, repeating: !reduceMotion) { view, p in
                        view.opacity(reduceMotion ? 0 : 0.55 * p).scaleEffect(0.8 + 0.4 * p)
                    } keyframes: { _ in breathCycle(index: index) }
            }
            .overlay {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Color(hex: 0xE9B872))
                    .keyframeAnimator(initialValue: 0.0, repeating: !reduceMotion) { view, p in
                        view.scaleEffect(reduceMotion ? 1 : 1 + 0.10 * p)
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

// MARK: 3 — Your first book (8c). Barcode is the design's fast path, but BookGate is on-device with
// no barcode/ISBN/network, so "Photograph the cover" is the path here (deliberate, per the brief).

struct AddBookStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var title = ""
    @State private var coverJPEG: Data?
    @State private var coverImage: UIImage?
    @State private var showCapture = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button("Skip") { next() }.font(BGFont.ui(14, .medium)).foregroundStyle(palette.ink(.secondary))
            }
            Spacer().frame(height: 2)
            Text("What are you reading?")
                .font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
            Text("Photograph the cover — it's the quickest way in. No barcode, no account.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)

            Button { showCapture = true } label: {
                Group {
                    if let coverImage {
                        Image(uiImage: coverImage).resizable().scaledToFill().frame(width: 128, height: 190).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.system(size: 22, weight: .light))
                                .foregroundStyle(palette.ink(.secondary))
                            Text("Photograph the cover").font(BGFont.ui(12.5, .medium)).foregroundStyle(palette.ink(.secondary))
                        }
                        .frame(width: 128, height: 190)
                        .background(RoundedRectangle(cornerRadius: 7).strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [5,4])).foregroundStyle(palette.hairline))
                    }
                }
            }.buttonStyle(.plain)

            quietRow(icon: "textformat", label: "Type it in myself", field: true)

            Spacer()
            Button("Continue") { addIfNeeded(); next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 26).padding(.top, 8).padding(.bottom, 40)
        .fullScreenCover(isPresented: $showCapture) {
            CoverCaptureView { jpeg, image, ocr in
                coverJPEG = jpeg; coverImage = image
                if title.isEmpty, let ocr, !ocr.isEmpty { title = ocr }
            }
        }
    }

    @ViewBuilder private func quietRow(icon: String, label: String, field: Bool) -> some View {
        TextField("", text: $title, prompt: Text("Type the title").foregroundStyle(palette.ink(.disabled)))
            .font(BGFont.row).foregroundStyle(palette.ink(.hero))
            .padding(14).glass(.quiet, cornerRadius: 16)
    }

    private func addIfNeeded() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let book = services.books.add(title: t, status: .reading)
        if let coverJPEG { services.books.setCover(coverJPEG, for: book) }
    }
}

// MARK: 4 — Length (5a)

struct LengthStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    private let rows: [(Int, String)] = [
        (5, "MINUTES"), (10, "MINUTES"), (15, "MINUTES"), (20, "MINUTES"),
        (30, "MINUTES"), (45, "MINUTES"), (60, "— for the deep end"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 6)
            Text("How long, to start?")
                .font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
            Text("Pick the length you'd never talk yourself out of.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(rows, id: \.0) { row(minutes: $0.0, suffix: $0.1) }
                }
            }

            growsNote
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }

    private func row(minutes: Int, suffix: String) -> some View {
        let isOn = minutes == services.settings.defaultLength
        let big = minutes == 60 ? "1 hour" : "\(minutes)"
        return Button { services.settings.defaultLength = minutes } label: {
            HStack(spacing: 8) {
                Text(big).font(BGFont.serif(20, .medium)).foregroundStyle(isOn ? palette.actionText : palette.ink(.hero))
                Text(minutes == 60 ? suffix : suffix.lowercased())
                    .font(BGFont.ui(11, .semibold)).tracking(0.8)
                    .foregroundStyle(isOn ? palette.actionText.opacity(0.75) : palette.ink(.secondary))
                Spacer()
                if minutes == 5 {
                    Text("RECOMMENDED").font(BGFont.ui(9.5, .bold)).tracking(0.6)
                        .foregroundStyle(isOn ? palette.actionText : palette.brassValue)
                }
            }
            .padding(.horizontal, 16).frame(height: 52).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isOn ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isOn ? Color.clear : palette.hairline, lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    private var growsNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("It grows with you").sectionLabel()
            Text("Read your minimum a week running and BookGate offers you the next step up. Only ever one step, only ever an offer.")
                .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glass(.quiet, cornerRadius: 16)
    }
}

// MARK: 5 — Shielded apps (8d)

struct AppsStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var showPicker = false

    var body: some View {
        @Bindable var shield = services.shield
        return VStack(spacing: 16) {
            Spacer().frame(height: 6)
            Text("Which apps usually win at 9pm?")
                .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("They'll be held back while you read. Nothing is deleted, nothing is reported.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)

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
        .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
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

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 6)
            Text("Four permissions, four reasons.")
                .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 11) {
                permRow("alarm.fill", "Alarms", "So 9pm actually reaches you, even on silent.", nil, alarmGranted) {
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
