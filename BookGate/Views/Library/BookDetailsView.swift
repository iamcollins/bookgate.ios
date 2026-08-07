import SwiftUI

/// Book details (screen 7b). Cover-derived header, the book's stats (sessions / read / takeaways,
/// brass on the takeaway count), a MY TAKEAWAYS timeline with brass bookmark nodes, and Pause /
/// Mark-finished. The schedule is shown, not editable (it is app-wide).
struct BookDetailsView: View {
    let bookID: UUID
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss

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
    }

    private var backButton: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink(.strong))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(palette.glassCard))
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
                Text(book.title).font(BGFont.serif(25, .medium))
                    .foregroundStyle(palette.ink(.hero)).lineLimit(3)
                if !book.author.isEmpty {
                    Text(book.author).font(BGFont.body).foregroundStyle(palette.ink(.body))
                }
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
                    Text("Play all \(takeaways.count)")
                        .font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
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

    private func timelineRow(_ t: Takeaway) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Bookmark(width: 12, height: 17)
                Rectangle().fill(palette.hairline).frame(width: 1).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(dayLabel(t.date)).font(BGFont.ui(13, .semibold)).foregroundStyle(palette.ink(.strong))
                    Text(durationLabel(t.durationSec)).font(BGFont.mono(12)).foregroundStyle(palette.ink(.secondary))
                }
                Text(t.transcript ?? "“…”")
                    .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body)).lineLimit(3)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footer(_ book: Book) -> some View {
        VStack(spacing: 12) {
            if book.status != .finished {
                Button(book.status == .paused ? "Resume reading" : "Pause reading") {
                    services.books.setStatus(book, book.status == .paused ? .reading : .paused)
                }
                .buttonStyle(GlassButtonStyle(minHeight: 50))
                Button("Mark finished") { services.books.setStatus(book, .finished) }
                    .buttonStyle(TextButtonStyle(ink: .secondary))
            } else {
                Button("Move back to reading") { services.books.startReading(book) }
                    .buttonStyle(GlassButtonStyle(minHeight: 50))
            }
        }
        .padding(.top, 8)
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
