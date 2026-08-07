import SwiftUI
import UserNotifications

// MARK: 1 — Welcome (8a)

struct WelcomeStep: View {
    var next: () -> Void
    var restore: () -> Void
    @Environment(\.bgPalette) private var palette
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack { markGlow; BookMark() }
            Spacer().frame(height: 52)
            Text("BOOKGATE")
                .font(BGFont.ui(11, .semibold)).tracking(2.4)
                .foregroundStyle(Color(hex: 0xE9B872))
            Text("Make reading\nhappen.")
                .font(BGFont.serif(38, .medium))
                .lineSpacing(38 * 0.2)
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
            Text("An alarm for your book, and a camera that makes sure you actually start.")
                .font(BGFont.ui(15.5, .regular)).lineSpacing(15.5 * 0.25)
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
                .font(BGFont.ui(13.5, .medium))
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
        .offset(y: reduceMotion ? 0 : (float ? -6 : 4))
        .animation(reduceMotion ? nil : .easeInOut(duration: 7).repeatForever(autoreverses: true), value: float)
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
    private let cards = [
        ("01", "Set your reading time", "One time, one length. It rings like an alarm, not a banner you swipe away."),
        ("02", "Show your book", "Hold the cover to the camera. That's what starts the session."),
        ("03", "Read without the noise", "The apps that usually win are held back until you finish."),
        ("04", "Say what mattered", "Thirty seconds in your own voice, kept under the book forever."),
    ]
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 6)
            Text("Four steps, every night.")
                .font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            VStack(spacing: 11) {
                ForEach(cards, id: \.0) { card in
                    HStack(alignment: .top, spacing: 14) {
                        Text(card.0).font(BGFont.serif(20, .medium)).foregroundStyle(palette.brassValue)
                            .frame(width: 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.1).font(BGFont.ui(15.5, .semibold)).foregroundStyle(palette.ink(.hero))
                            Text(card.2).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                        }
                        Spacer()
                    }
                    .padding(14).frame(maxWidth: .infinity).glass(.card, cornerRadius: 18)
                }
            }
            Spacer()
            Button("Set it up") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
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
