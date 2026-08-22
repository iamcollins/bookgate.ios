import SwiftUI
import FamilyControls

/// Today (screen 4b / light 2a). The book is the screen: its cover bleeds off the top under a
/// wordmark row; a bottom glass sheet carries Tonight, the one primary action, and the last
/// takeaway. Variants: missed-yesterday (calm, quiet chip, no red) and already-read-today
/// (primary becomes secondary).
struct TodayView: View {
    /// Sends the reader to Library. Supplied by the tab shell, which owns the selection.
    var onOpenLibrary: () -> Void = {}
    /// Sends the reader to Progress — where the streak chip goes when tapped.
    var onOpenProgress: () -> Void = {}

    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    @State private var showLengthSheet = false
    @State private var showSettings = false
    @State private var showAddBook = false
    @State private var player = AudioPlayer()

    private var book: Book? { services.books.currentReading }
    /// With no book there is no cover, so the header is bare ambient and its chrome takes ink
    /// from the palette instead of the cream that only ever worked over dark cloth.
    private var hasBook: Bool { book != nil }
    private var libraryIsEmpty: Bool { services.books.books.isEmpty }
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
                if hasBook {
                    coverHeader(height: coverHeight, width: geo.size.width)
                }

                VStack(spacing: 0) {
                    wordmarkRow
                        .padding(.horizontal, 20)
                        .padding(.top, geo.safeAreaInsets.top + 6)
                    Spacer(minLength: 0)
                    if !hasBook {
                        chooseBookPrompt
                            .padding(.horizontal, 28)
                        Spacer(minLength: 0)
                    }
                    bottomSheet
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)   // the system tab bar insets the rest
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showLengthSheet) {
                // A sheet is its own presentation with its own trait collection: the
                // `preferredColorScheme` set out on the tab shell does not reach it, so a sheet
                // left open across a theme change kept the old system material under the new ink.
                // Invisible while the glass was ours — the palette *is* inherited — and plain the
                // moment the material became the system's.
                TonightLengthSheet()
                .environment(services)
                .themedRoot(services.settings.theme)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .environment(services)
                .themedRoot(services.settings.theme)
        }
        // Straight to the sheet. Sending a reader with no books to Library only to have them
        // press Add there was a step that existed for the code's benefit, not theirs.
        .sheet(isPresented: $showAddBook) {
            AddBookView()
                .environment(services)
                .themedRoot(services.settings.theme)
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
            // Top scrim, both themes: the cover is an object and stays dark on paper too, so the
            // cream wordmark row needs the same band it gets at night.
            //
            // Carried a third of the way down rather than dying at 24%. The cloth's own gradient
            // peaks at #8A6A4E around the title, and with nothing over it the upper third read as
            // a pale wall — the scrim is the only lever that can weight it, because the cover is
            // an object and its colours are theme-independent. Stops end before the paper sink
            // starts at 30%, so the two never mix into grey.
            .overlay {
                LinearGradient(stops: [
                    .init(color: Color(hex: 0x100C09, opacity: 0.66), location: 0.00),
                    .init(color: Color(hex: 0x100C09, opacity: 0.50), location: 0.12),
                    .init(color: Color(hex: 0x100C09, opacity: 0.26), location: 0.26),
                    .init(color: Color(hex: 0x100C09, opacity: 0.00), location: 0.42),
                ], startPoint: .top, endPoint: .bottom)
            }
            // The sink. On light the header "fades into paper rather than into black" (handoff
            // 11b) — sinking it into #100C09 on a cream page was what turned the lower half of
            // the cover into a grey bruise.
            .overlay {
                LinearGradient(stops: [
                    .init(color: sink.opacity(0.00), location: 0.30),
                    .init(color: sink.opacity(0.34), location: 0.66),
                    .init(color: sink.opacity(0.86), location: 0.88),
                    .init(color: sink.opacity(1.00), location: 1.00),
                ], startPoint: .top, endPoint: .bottom)
            }
            // …and it dissolves rather than stopping. No opaque colour can end the header
            // cleanly: behind it sit the ambient wash and two drifting blobs, all of them a
            // different value at the cover's edge than `base` is. That mismatch is the hard line
            // across the light screen. Fading the header's *alpha* to nothing lands it on
            // whatever is actually back there, in either theme.
            .mask {
                LinearGradient(stops: [
                    .init(color: .white, location: 0.00),
                    .init(color: .white, location: 0.62),
                    .init(color: .white.opacity(0.74), location: 0.79),
                    .init(color: .white.opacity(0.34), location: 0.90),
                    .init(color: .white.opacity(0.10), location: 0.96),
                    .init(color: .white.opacity(0.00), location: 1.00),
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    /// What the header sinks into: the night floor on dark, paper on light.
    private var sink: Color { palette.isDark ? Color(hex: 0x100C09) : palette.base }

    /// The fallback cover: warm cloth and the book set in the serif — `BookCoverView`'s language
    /// scaled up to the header.
    ///
    /// No spine. `BookCoverView` draws one because that cover is a bounded object with a visible
    /// edge for the crease to sit next to; here the cloth bleeds off all four sides, so the same
    /// rule 13pt from the screen edge reads as a scratch down the page rather than as a binding —
    /// which is exactly how it landed on paper.
    private func typographicCover(_ book: Book?, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x6D5340), Color(hex: 0x8A6A4E), Color(hex: 0x5D4635)],
                           startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1))
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

    // MARK: The reader has no book yet

    /// What the header becomes with nothing to show. Drawing the cloth cover anyway — which is
    /// what "Your book" was — puts a book on the screen that does not exist, and the one thing
    /// this screen needs to say is which book it should be.
    private var chooseBookPrompt: some View {
        VStack(spacing: 16) {
            Text("What are you reading?")
                .font(BGFont.serif(30, .medium))
                .foregroundStyle(palette.ink(.hero))
                .multilineTextAlignment(.center)
            Button {
                if libraryIsEmpty { showAddBook = true } else { onOpenLibrary() }
            } label: {
                HStack(spacing: 7) {
                    Text(libraryIsEmpty ? "Add your first book" : "Choose a book")
                        .font(BGFont.ui(14.5, .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(palette.brassValue)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glass(.card, cornerRadius: 21, interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Wordmark row

    /// Cream while it sits on the dark cover; palette ink once the cover is gone, or it would be
    /// invisible against paper.
    private var headerInk: Color {
        hasBook ? Color(hex: 0xF7EFE4, opacity: 0.75) : palette.ink(.secondary)
    }

    private var wordmarkRow: some View {
        HStack(alignment: .center) {
            Text("BOOKGATE")
                .font(BGFont.ui(10.5, .semibold)).tracking(1.6)
                .foregroundStyle(headerInk)
            Spacer()
            streakChip
            Button { showSettings = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(headerInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder private var streakChip: some View {
        let chip = HStack(spacing: 6) {
            BookmarkShape(notch: 0.74).fill(palette.brassObject).frame(width: 10, height: 14)
            Text("\(streak)")
                .font(BGFont.serif(15, .medium))
                .foregroundStyle(hasBook ? Color(hex: 0xF2D6AB) : palette.brassValue)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)

        // It looks like a control and reads like one, so it is: the streak's own screen is
        // Progress, and the alternative — flattening it until nobody tries — spends the
        // instinct rather than rewarding it.
        Button { onOpenProgress() } label: {
            Group {
                if hasBook {
                    // A scrim capsule, because the cover behind it is a photograph and glass
                    // would take its colour from whatever happens to be printed there.
                    chip.background(Capsule().fill(Color(hex: 0x140E09, opacity: 0.38)))
                } else {
                    chip.glass(.card, cornerRadius: 14)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(missedYesterday ? 0.55 : 1)      // chip goes quiet on a miss — no red, no drama
        .accessibilityLabel("\(streak) night streak")
        .accessibilityHint("Opens Progress")
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

            scheduleBlock

            actionArea

            lastTakeawayRow
        }
        .padding(18)
        .glass(.prominent, cornerRadius: 28)
    }

    /// The action. Which one it is depends on **where the clock is**, not on what the reader has
    /// already done.
    ///
    /// Inside the scheduled window — the start time through its duration, so arriving a few
    /// minutes late still counts — reading is the session the app asked for, and takes the brass.
    /// Outside it, before or after, reading is something the reader added: it still runs the whole
    /// flow and still counts, but it is their idea rather than the app's, so it takes the quiet
    /// button. With nothing scheduled at all there is no window and no competition, so reading now
    /// simply is the session.
    ///
    /// An earlier version of this branched on "have they read today", which produced states that
    /// disagreed with the clock — a loud Start Reading at four in the afternoon against a nine
    /// o'clock schedule.
    @ViewBuilder private var actionArea: some View {
        if isScheduledMoment {
            VStack(spacing: 8) {
                Button("Start Reading") { beginReading() }
                    .buttonStyle(PrimaryActionButtonStyle())
                Text(reassurance)
                    .font(BGFont.aside(13.5)).foregroundStyle(palette.ink(.secondary))
            }
        } else {
            Button("Log a session") { beginReading() }
                .buttonStyle(GlassButtonStyle(minHeight: 56))
        }
    }

    /// True inside today's scheduled window, and true when nothing is scheduled at all.
    private var isScheduledMoment: Bool {
        guard let alarm, alarm.isOn, alarm.days.contains(true) else { return true }
        guard let window = alarm.window(on: .now, minutes: services.settings.effectiveTonightLength)
        else { return false }                      // an inactive night: no session was asked for
        return window.contains(Date())
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

    /// Time · length, and beneath it the shield — two separate things that tap to two separate
    /// places, in one bordered block the way the handoff's card carries its shield footer.
    ///
    /// They used to be one row: the subtitle read "Choose apps to shield · tap to change" while
    /// tapping opened the *length* sheet. The line promised something the tap did not do.
    private var scheduleBlock: some View {
        VStack(spacing: 0) {
            Button { showLengthSheet = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scheduleLabel).sectionLabel()
                        Text("\(timeLabel) · \(lengthLabel)")
                            .font(BGFont.serif(22, .medium))
                            .foregroundStyle(palette.ink(.hero))
                        Text(alarm?.dayLabel ?? String(localized: "Every night"))
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change the reading time and length")

            Hairline().padding(.horizontal, 14)

            TonightShieldRow(shield: services.shield)
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(palette.hairline, lineWidth: 1))
    }

    /// What to call the next session. The schedule takes any minute of the day, so this is only
    /// "Tonight" when it actually is: a 10:00 AM reading time used to be announced as "TONIGHT".
    private var scheduleLabel: String {
        let minute = alarm?.readingMin ?? 1260
        // Inside the window the session is happening *now*, so ask the clock about today. Going
        // straight to `nextOccurrence` looks past it — a minute after the start it already points
        // at tomorrow, and the card announced "TOMORROW" over a live Start Reading button.
        if isScheduledMoment, alarm != nil { return Schedule.periodLabel(forMinuteOfDay: minute) }
        guard let next = alarm?.nextOccurrence() else {
            return Schedule.periodLabel(forMinuteOfDay: minute)
        }
        let cal = Calendar.current
        if cal.isDateInToday(next) { return Schedule.periodLabel(forMinuteOfDay: minute) }
        if cal.isDateInTomorrow(next) { return String(localized: "Tomorrow") }
        return next.formatted(.dateTime.weekday(.wide))
    }

    /// One encouraging line under the action, and it has to hold at every length.
    ///
    /// The handoff's "Five minutes is enough to begin." was written for the five-minute default,
    /// and its point was that the commitment is *small* — so starting is easy. Templating the
    /// number in kept the sentence and lost the argument: "1 hour is enough to begin" tells a
    /// reader their long commitment is a low bar. It also repeated a number the row above already
    /// states. What is true at five minutes and at an hour is that the starting is the hard part.
    private let reassurance = String(localized: "The hardest part is opening the book.")

    /// The compact "last takeaway" player row (design 4b): play circle, one-line italic quote,
    /// timecodes. Plays inline. Hidden when there are no takeaways.
    @ViewBuilder private var lastTakeawayRow: some View {
        if let t = services.takeaways.latest {
            let active = player.currentID == t.id
            Button { player.toggle(t, url: services.takeaways.audioURL(for: t)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: (active && player.isPlaying) ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.brassValue)
                        .frame(width: 38, height: 38)
                        .glassCircle(.prominent)
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

/// The shield, on Today. Its own row and its own destination: tapping opens Apple's picker, which
/// is the thing "choose apps to shield" was always promising.
private struct TonightShieldRow: View {
    @Bindable var shield: ShieldManager
    @Environment(\.bgPalette) private var palette
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: shield.shieldedCount == 0 ? "lock.open" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.brassValue)
                Text(label)
                    .font(BGFont.caption)
                    .foregroundStyle(palette.ink(.body))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.ink(.secondary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .familyActivityPicker(isPresented: $showPicker, selection: $shield.selection)
        .accessibilityHint("Choose which apps are locked during a session")
    }

    private var label: String {
        let n = shield.shieldedCount
        if n == 0 { return String(localized: "Choose apps to shield") }
        return String(localized: "\(n) apps shielded during your session")
    }
}
