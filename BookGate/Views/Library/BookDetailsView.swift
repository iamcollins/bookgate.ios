import SwiftUI

/// Book details (screen 7b). Cover-derived header, the book's stats (sessions / read / takeaways,
/// brass on the takeaway count), a MY TAKEAWAYS timeline with brass bookmark nodes, and Pause /
/// Mark-finished. The schedule is shown, not editable (it is app-wide).
struct BookDetailsView: View {
    let bookID: UUID
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var player = AudioPlayer()
    @State private var confirmDelete = false
    /// Renaming. Cover OCR picks the largest text on a jacket, which is very often the author or a
    /// strapline — so a wrong title was permanent, on the one screen that is all about that book.
    @State private var renaming = false
    @State private var draftTitle = ""
    @State private var draftAuthor = ""

    private var book: Book? { services.books.books.first { $0.id == bookID } }
    private var takeaways: [Takeaway] { book.map { services.takeaways.takeaways(forBook: $0.idString) } ?? [] }

    var body: some View {
        ZStack(alignment: .top) {
            palette.base.ignoresSafeArea()
            if let book {
                coverHeader(book)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 150)
                        headerBlock(book)
                        statsPanel(book)
                        JournalPhotoStrip(bookID: book.idString)
                        takeawaysTimeline(book)
                        footer(book)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
                backButton
            } else {
                Color.clear
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { player.stop() }
        .confirmationDialog("Remove this book?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove book", role: .destructive) {
                if let book { services.books.delete(book) }
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its cover and reading history go with it. Your takeaways are kept.")
        }
        .alert("Edit book", isPresented: $renaming) {
            TextField("Title", text: $draftTitle)
            TextField("Author", text: $draftAuthor)
            Button("Save") { saveEdits() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var backButton: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink(.strong))
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }

    private func coverHeader(_ book: Book) -> some View {
        LinearGradient(colors: [Color(hex: 0x6D5340), Color(hex: 0x3A2C22)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 300)
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: palette.base, location: 1),
                ], startPoint: .top, endPoint: .bottom).frame(height: 160)
            }
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)
    }

    private func headerBlock(_ book: Book) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            BookCoverView(book: book, image: services.books.coverImage(for: book), width: 104, height: 154)
            VStack(alignment: .leading, spacing: 6) {
                Button { beginRename(book) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(book.title).font(BGFont.serif(25, .medium))
                                .foregroundStyle(palette.ink(.hero)).lineLimit(3)
                                .multilineTextAlignment(.leading)
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.ink(.caption))
                        }
                        if !book.author.isEmpty {
                            Text(book.author).font(BGFont.body).foregroundStyle(palette.ink(.body))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(book.title). Edit title and author.")
                statusChip(book.status)
                Text(sinceLabel(book))
                    .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func statusChip(_ status: BookStatus) -> some View {
        Text(statusLabel(status))
            .sectionLabel()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
    }

    private func statsPanel(_ book: Book) -> some View {
        HStack(spacing: 0) {
            stat("\(book.sessionsRead)", "sessions", brass: false)
            Hairline(axis: .vertical).frame(height: 40)
            stat(readLabel(book.minutesRead), "read", brass: false)
            Hairline(axis: .vertical).frame(height: 40)
            stat("\(services.takeaways.count(forBook: book.idString))", "takeaways", brass: true)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .glass(.card, cornerRadius: 22)
    }

    private func stat(_ value: String, _ label: String, brass: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value).font(BGFont.serif(27, .medium))
                .foregroundStyle(brass ? palette.brassValue : palette.ink(.hero))
            Text(label).sectionLabel(color: palette.ink(.secondary))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func takeawaysTimeline(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My takeaways").sectionLabel()
                Spacer()
                if !takeaways.isEmpty {
                    // This was plain text pretending to be a button — the count was right and
                    // nothing happened when you tapped it.
                    Button {
                        player.playAll(takeaways.reversed().map { ($0, services.takeaways.audioURL(for: $0)) })
                    } label: {
                        Text(player.isPlayingQueue ? "Stop" : "Play all \(takeaways.count)")
                            .font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            if takeaways.isEmpty {
                Text("No takeaways yet. Record one after a session.")
                    .font(BGFont.body).foregroundStyle(palette.ink(.secondary))
            } else {
                ForEach(takeaways) { t in timelineRow(t) }
            }
        }
    }

    /// A takeaway on the book's timeline. It plays here: a reader looking at a book's page is
    /// exactly the reader who wants to hear what they said about it, and until now this row was
    /// inert text with an empty quote mark where a transcript would have been.
    private func timelineRow(_ t: Takeaway) -> some View {
        let active = player.currentID == t.id
        return Button {
            player.toggle(t, url: services.takeaways.audioURL(for: t))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Bookmark(width: 12, height: 17)
                    Rectangle().fill(palette.hairline).frame(width: 1).frame(maxHeight: .infinity)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(dayLabel(t.date)).font(BGFont.ui(13, .semibold)).foregroundStyle(palette.ink(.strong))
                        Text(durationLabel(t.durationSec)).font(BGFont.mono(12)).foregroundStyle(palette.ink(.secondary))
                    }
                    WaveformView(levels: t.waveform ?? [],
                                 progress: active ? player.progress : 0,
                                 height: 20)
                        .frame(height: 20)
                }
                Spacer(minLength: 8)
                Image(systemName: (active && player.isPlaying) ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(active ? palette.brassValue : palette.ink(.secondary))
                    .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Takeaway from \(dayLabel(t.date)), \(durationLabel(t.durationSec))")
    }

    /// What you can do with a book, matched to where it actually is. A book on the *next up* shelf
    /// used to be offered "Pause reading" — an action for a book it wasn't — and no shelf offered
    /// any way to remove a book at all.
    @ViewBuilder private func footer(_ book: Book) -> some View {
        VStack(spacing: 12) {
            switch book.status {
            case .reading:
                Button("Pause reading") { services.books.setStatus(book, .paused) }
                    .buttonStyle(GlassButtonStyle(minHeight: 50))
                Button("Mark finished") { services.books.setStatus(book, .finished) }
                    .buttonStyle(TextButtonStyle(ink: .secondary))
            case .next, .paused:
                Button(book.status == .paused ? "Pick it back up" : "Start reading this") {
                    services.books.startReading(book)
                }
                .buttonStyle(GlassButtonStyle(minHeight: 50))
                Button("Mark finished") { services.books.setStatus(book, .finished) }
                    .buttonStyle(TextButtonStyle(ink: .secondary))
            case .finished:
                Button("Read it again") { services.books.startReading(book) }
                    .buttonStyle(GlassButtonStyle(minHeight: 50))
            }
            Button("Remove from library") { confirmDelete = true }
                .buttonStyle(TextButtonStyle(ink: .caption))
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func beginRename(_ book: Book) {
        draftTitle = book.title
        draftAuthor = book.author
        renaming = true
    }

    private func saveEdits() {
        guard var book else { return }
        let t = draftTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }          // a book with no name is not an improvement
        book.title = t
        book.author = draftAuthor.trimmingCharacters(in: .whitespaces)
        services.books.update(book)
    }

    // MARK: Labels

    private func statusLabel(_ s: BookStatus) -> String {
        switch s {
        case .reading: return String(localized: "Reading")
        case .next: return String(localized: "Next up")
        case .paused: return String(localized: "Paused")
        case .finished: return String(localized: "Finished")
        }
    }
    private func sinceLabel(_ book: Book) -> String {
        let date = book.startedDate ?? book.addedDate
        let df = DateFormatter(); df.dateFormat = "d MMMM"
        let time = services.store.schedule(for: nil)?.timeLabel ?? "9:00 PM"
        return String(localized: "Since \(df.string(from: date)) · \(time) nightly")
    }
    private func readLabel(_ minutes: Int) -> String {
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
    private func dayLabel(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEE d MMM"; return df.string(from: date)
    }
    private func durationLabel(_ sec: Double) -> String {
        let s = Int(sec.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
