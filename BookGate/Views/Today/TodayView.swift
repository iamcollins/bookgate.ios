import SwiftUI

/// Today (screen 4b / light 2a). The book is the screen: its cover bleeds off the top under a
/// wordmark row; a bottom glass sheet carries Tonight, the one primary action, and the last
/// takeaway. Variants: missed-yesterday (calm, quiet chip, no red) and already-read-today
/// (primary becomes secondary).
struct TodayView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    @State private var showLengthSheet = false
    @State private var showSettings = false
    @State private var player = AudioPlayer()

    private var book: Book? { services.books.currentReading }
    private var streak: Int { services.progress.liveStreak }
    private var readToday: Bool { services.progress.readToday }
    private var missedYesterday: Bool { services.progress.missedYesterday }
    private var alarm: Schedule? { services.store.schedule(for: nil) }

    private var timeLabel: String { alarm?.timeLabel ?? "9:00 PM" }
    private var lengthLabel: String { "\(services.settings.effectiveTonightLength) min" }

    var body: some View {
        GeometryReader { geo in
            // The cover carries the screen down to the sheet. A flat 440pt cap left a band of bare
            // background between the two on a large phone — the book stopped, and nothing took over.
            let coverHeight = geo.size.height * 0.58
            ZStack(alignment: .top) {
                coverHeader(height: coverHeight, width: geo.size.width)

                VStack(spacing: 0) {
                    wordmarkRow
                        .padding(.horizontal, 20)
                        .padding(.top, geo.safeAreaInsets.top + 6)
                    Spacer(minLength: 0)
                    bottomSheet
                        .padding(.horizontal, 20)
                        .padding(.bottom, 104)   // clear the floating tab bar
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showLengthSheet) {
            TonightLengthSheet()
                .environment(services)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .environment(services)
        }
    }

    // MARK: Cover header

    private func coverHeader(height: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Group {
                if let book, let img = services.books.coverImage(for: book) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    // No photograph yet — so the header becomes the cover, set the way a cloth
                    // binding is. Previously this was a bare gradient: half the screen of empty
                    // brown, with the book's name nowhere on its own home screen.
                    typographicCover(book, width: width, height: height)
                }
            }
            .frame(width: width, height: height)
            .clipped()
            // Scrim: dark at top for wordmark legibility, fading to the theme base at the bottom.
            .overlay {
                LinearGradient(stops: [
                    .init(color: Color(hex: 0x100C09, opacity: 0.55), location: 0.0),
                    .init(color: .clear, location: 0.24),
                    .init(color: Color(hex: 0x100C09, opacity: 0.34), location: 0.66),
                    .init(color: palette.base, location: 1.0),
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    /// The fallback cover: warm cloth, a spine line, and the book set in the serif — the same
    /// language as `BookCoverView`, scaled up to the header.
    private func typographicCover(_ book: Book?, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x6D5340), Color(hex: 0x8A6A4E), Color(hex: 0x5D4635)],
                           startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1))
            Rectangle().fill(Color.black.opacity(0.25))
                .frame(width: 1.5)
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(book?.title ?? String(localized: "Your book"))
                    .font(BGFont.serif(36, .medium))
                    .foregroundStyle(Color(hex: 0xFBF5EA))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 3)
                if let author = book?.author, !author.isEmpty {
                    Text(author)
                        .font(BGFont.aside(16))
                        .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.78))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                }
            }
            .padding(.leading, 34)
            .padding(.trailing, 28)
            // Set where a cover sets its title, and — just as importantly — in the band where the
            // scrim is clear. Lower down, the fade into the sheet washed the type out to grey.
            .padding(.top, height * 0.30)
        }
    }

    // MARK: Wordmark row (always over the dark cover → light ink)

    private var wordmarkRow: some View {
        HStack(alignment: .center) {
            Text("BOOKGATE")
                .font(BGFont.ui(10.5, .semibold)).tracking(1.6)
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.75))
            Spacer()
            streakChip
            Button { showSettings = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.75))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var streakChip: some View {
        HStack(spacing: 6) {
            BookmarkShape(notch: 0.74).fill(palette.brassObject).frame(width: 10, height: 14)
            Text("\(streak)")
                .font(BGFont.serif(15, .medium))
                .foregroundStyle(Color(hex: 0xF2D6AB))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color(hex: 0x140E09, opacity: 0.38)))
        .opacity(missedYesterday ? 0.55 : 1)      // chip goes quiet on a miss — no red, no drama
        .accessibilityLabel("\(streak) night streak")
    }

    // MARK: Bottom glass sheet

    private var bottomSheet: some View {
        VStack(spacing: 16) {
            if let note = statusNote {
                Text(note)
                    .font(BGFont.aside(14.5))
                    .foregroundStyle(palette.ink(.body))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            tonightRow

            if readToday {
                Button("You've read today") {}
                    .buttonStyle(GlassButtonStyle(minHeight: 56))
                    .disabled(true)
            } else {
                VStack(spacing: 8) {
                    Button("Start Reading") { beginReading() }
                        .buttonStyle(PrimaryActionButtonStyle())
                    Text(reassurance)
                        .font(BGFont.aside(13.5)).foregroundStyle(palette.ink(.secondary))
                }
            }

            lastTakeawayRow
        }
        .padding(18)
        .glass(.prominent, cornerRadius: 28)
    }

    /// One calm line above tonight's row, or nothing at all. A rest day is named as the rule
    /// Settings promises, so a kept streak after a missed night never looks like a bug.
    private var statusNote: String? {
        guard !readToday else { return nil }
        if services.progress.onRestDay {
            return String(localized: "Last night was your rest day. The streak still stands.")
        }
        if missedYesterday {
            return String(localized: "Last night slipped by. Tonight is a fresh page.")
        }
        return nil
    }

    private var tonightRow: some View {
        Button { showLengthSheet = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tonight").sectionLabel()
                    Text("\(timeLabel) · \(lengthLabel)")
                        .font(BGFont.serif(22, .medium))
                        .foregroundStyle(palette.ink(.hero))
                    Text(shieldSubtitle)
                        .font(BGFont.caption)
                        .foregroundStyle(palette.ink(.secondary))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.ink(.secondary))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Change tonight's reading length")
    }

    private var shieldSubtitle: String {
        let n = services.shield.shieldedCount
        if n == 0 { return String(localized: "Choose apps to shield · tap to change") }
        return String(localized: "\(n) apps shielded · tap to change")
    }

    private var reassurance: String {
        let n = services.settings.effectiveTonightLength
        return n == 5 ? String(localized: "Five minutes is enough to begin.")
                      : String(localized: "\(n) minutes is enough to begin.")
    }

    /// The compact "last takeaway" player row (design 4b): play circle, one-line italic quote,
    /// timecodes. Plays inline. Hidden when there are no takeaways.
    @ViewBuilder private var lastTakeawayRow: some View {
        if let t = services.takeaways.latest {
            let active = player.currentID == t.id
            Button { player.toggle(t, url: services.takeaways.audioURL(for: t)) } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(palette.glassProminent).frame(width: 38, height: 38)
                        Image(systemName: (active && player.isPlaying) ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(palette.brassValue)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Last takeaway").sectionLabel(color: palette.ink(.caption))
                        Text(takeawayLabel(t))
                            .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).lineLimit(1)
                    }
                    Spacer()
                    Text("\(timeStr(active ? player.currentTime : 0)) / \(timeStr(t.durationSec))")
                        .font(BGFont.mono(11)).foregroundStyle(palette.ink(.secondary))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// What the takeaway row says. There is no transcript (nothing is sent anywhere to make one),
    /// so it says *when* — which is what you actually want when deciding whether to replay it.
    private func takeawayLabel(_ t: Takeaway) -> String {
        if let book = t.bookId.flatMap({ services.books.book(id: $0) }) { return book.title }
        return t.date.formatted(.relative(presentation: .named)).localizedCapitalized
    }

    private func timeStr(_ t: TimeInterval) -> String {
        let s = Int(t.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Actions

    private func beginReading() {
        services.session.beginReadingNow()
    }
}
