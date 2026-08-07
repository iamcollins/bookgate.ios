import SwiftUI
import UserNotifications

// MARK: 1 — Welcome (8a)

struct WelcomeStep: View {
    var next: () -> Void
    var restore: () -> Void
    @Environment(\.bgPalette) private var palette
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Bookmark(width: 42, height: 58)
            Text("Make reading happen.")
                .font(BGFont.serif(33, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            Text("An alarm for your book. Read before you scroll.")
                .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get started") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
            Button("Restore purchase") { restore() }.buttonStyle(TextButtonStyle(ink: .secondary))
        }
        .padding(.horizontal, 26).padding(.bottom, 40)
    }
}

// MARK: 2 — How it works (8b)

struct HowItWorksStep: View {
    var next: () -> Void
    @Environment(\.bgPalette) private var palette
    private let cards = [
        ("Set a nightly alarm", "At a time you choose, BookGate rings — a bookmark, not a buzzer."),
        ("Show your book", "Hold it up to the camera to dismiss the alarm and start."),
        ("Read while apps stay shut", "The apps that usually win the hour are locked until you finish."),
        ("Keep what you read", "A nightly photo journal and a spoken takeaway, just for you."),
    ]
    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Text("How it works").font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
            VStack(spacing: 12) {
                ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(i + 1)").font(BGFont.serif(20, .medium)).foregroundStyle(palette.brassValue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.0).font(BGFont.ui(15.5, .semibold)).foregroundStyle(palette.ink(.hero))
                            Text(card.1).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                        }
                        Spacer()
                    }
                    .padding(14).frame(maxWidth: .infinity).glass(.card, cornerRadius: 18)
                }
            }
            Spacer()
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }
}

// MARK: 3 — Add your book (8c, skippable)

struct AddBookStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var title = ""
    @State private var coverJPEG: Data?
    @State private var coverImage: UIImage?
    @State private var showCapture = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Text("Add your book").font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
            Text("Photograph the cover, or type the title. No barcode, no account.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)

            Button { showCapture = true } label: {
                Group {
                    if let coverImage {
                        Image(uiImage: coverImage).resizable().scaledToFill().frame(width: 130, height: 192).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.system(size: 22, weight: .light))
                                .foregroundStyle(palette.ink(.secondary))
                            Text("Photograph the cover").font(BGFont.ui(12.5, .medium)).foregroundStyle(palette.ink(.secondary))
                        }
                        .frame(width: 130, height: 192)
                        .background(RoundedRectangle(cornerRadius: 7).strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [5,4])).foregroundStyle(palette.hairline))
                    }
                }
            }.buttonStyle(.plain)

            TextField("", text: $title, prompt: Text("Book title").foregroundStyle(palette.ink(.disabled)))
                .font(BGFont.row).foregroundStyle(palette.ink(.hero))
                .padding(14).glass(.card, cornerRadius: 16)

            Spacer()
            Button("Continue") { addIfNeeded(); next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
            Button("Skip for now") { next() }.buttonStyle(TextButtonStyle(ink: .secondary))
        }
        .padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 40)
        .fullScreenCover(isPresented: $showCapture) {
            CoverCaptureView { jpeg, image, ocr in
                coverJPEG = jpeg; coverImage = image
                if title.isEmpty, let ocr, !ocr.isEmpty { title = ocr }
            }
        }
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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Text("How long each night?").font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            Text("Start small. It earns its way up on its own.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body))
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ReadingSettings.lengthOptions, id: \.self) { v in chip(v) }
            }
            Spacer()
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }

    private func chip(_ v: Int) -> some View {
        let isOn = v == services.settings.defaultLength
        let label = v == 60 ? "1h" : "\(v)m"
        return Button { services.settings.defaultLength = v } label: {
            VStack(spacing: 3) {
                Text(label).font(BGFont.serif(20, .medium))
                    .foregroundStyle(isOn ? palette.actionText : palette.ink(.strong))
                if v == 5 { Text("PICK").font(BGFont.ui(7.5, .bold)).tracking(0.5)
                    .foregroundStyle(isOn ? palette.actionText.opacity(0.7) : palette.brassValue) }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isOn ? AnyShapeStyle(palette.brassObject) : AnyShapeStyle(Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isOn ? Color.clear : palette.hairline, lineWidth: 1)))
        }.buttonStyle(.plain)
    }
}

// MARK: 5 — Shielded apps (8d)

struct AppsStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Text("Lock the apps that win the hour")
                .font(BGFont.serif(29, .medium)).foregroundStyle(palette.ink(.hero)).multilineTextAlignment(.center)
            Text("They stay shut from your alarm until your session is done, then unlock.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)
            ShieldAppsRow(shield: services.shield).glass(.card, cornerRadius: 18)
            Spacer()
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
            Button("Choose later") { next() }.buttonStyle(TextButtonStyle(ink: .secondary))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }
}

// MARK: 6 — Permissions (8e), granted one at a time

struct PermissionsStep: View {
    var next: () -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var camGranted = false
    @State private var alarmGranted = false
    @State private var screenTimeGranted = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Text("A few permissions").font(BGFont.serif(31, .medium)).foregroundStyle(palette.ink(.hero))
            Text("Each does one thing. Grant them one at a time — a no won't break setup.")
                .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).multilineTextAlignment(.center)
            VStack(spacing: 12) {
                permRow("camera.fill", "Camera", "Show your book at night and save the journal photo.", camGranted) {
                    Task { camGranted = (await CameraAccess.request()) == .authorized }
                }
                permRow("alarm.fill", "Reading alarm", "Ring through Silent mode and Focus.", alarmGranted) {
                    Task { alarmGranted = await services.scheduler.requestAuthorization() }
                }
                permRow("hourglass", "Screen Time", "Lock distracting apps during your session.", screenTimeGranted) {
                    Task { screenTimeGranted = await services.shield.requestAuthorization() }
                }
            }
            Spacer()
            Button("Continue") { next() }.buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 40)
    }

    private func permRow(_ symbol: String, _ title: String, _ why: String, _ granted: Bool, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(palette.brassValue).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BGFont.ui(15, .semibold)).foregroundStyle(palette.ink(.hero))
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
