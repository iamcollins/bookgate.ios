import SwiftUI
import UserNotifications

// MARK: 1 — Welcome (8a)

struct WelcomeStep: View {
    var next: () -> Void
    var restore: () -> Void
    @Environment(\.bgPalette) private var palette
    var body: some View {
        VStack(spacing: 0) {
            Text("BOOKGATE")
                .font(BGFont.ui(11, .semibold)).tracking(2.0)
                .foregroundStyle(palette.ink(.secondary))
                .padding(.top, 8)
            Spacer()
            markOnPageEdge
            Spacer().frame(height: 30)
            Text("Make reading happen.")
                .font(BGFont.serif(33, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            Text("An alarm for your book, and a camera that makes sure you actually start.")
                .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
                .padding(.top, 10).padding(.horizontal, 8)
            Spacer()
            Button("Get Started") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 58))
            Button { restore() } label: {
                HStack(spacing: 4) {
                    Text("Already subscribed?").foregroundStyle(palette.ink(.secondary))
                    Text("Restore").foregroundStyle(palette.brassValue)
                }
                .font(BGFont.ui(13.5, .medium))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 26).padding(.bottom, 40)
    }

    /// The mark is the motif — a brass bookmark laid on a page edge.
    private var markOnPageEdge: some View {
        ZStack(alignment: .top) {
            // page edge behind the bookmark
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0xF7EFE4, opacity: palette.isDark ? 0.06 : 0.5))
                .frame(width: 116, height: 150)
                .overlay(alignment: .leading) {
                    Rectangle().fill(palette.hairline).frame(width: 1).padding(.leading, 10)
                }
                .offset(x: 20, y: 10)
            Bookmark(width: 42, height: 58)
                .offset(x: -18)
        }
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
                .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
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
                .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
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
