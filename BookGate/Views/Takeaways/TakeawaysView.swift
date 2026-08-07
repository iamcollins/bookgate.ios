import SwiftUI

/// Takeaways (screen 7c). "N recordings · M minutes of you", grouped per book with Play all. The
/// playing row expands in place into a play/pause circle, day·date, timecodes, and a waveform.
/// Newest first, grouped by book.
struct TakeawaysView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var player = AudioPlayer()

    private var store: TakeawayStore { services.takeaways }

    var body: some View {
        ZStack {
            BGAmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if store.takeaways.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.groupedByBook(), id: \.bookId) { group in
                            bookGroup(group.bookId, group.items)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 120)
            }
            .scrollContentBackground(.hidden)
        }
        .onDisappear { player.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Takeaways").font(BGFont.screenTitle).foregroundStyle(palette.ink(.hero))
            Text(subtitle).font(BGFont.body).foregroundStyle(palette.ink(.secondary))
        }
    }

    private var subtitle: String {
        let mins = Int((store.totalSeconds / 60).rounded())
        return String(localized: "\(store.totalCount) recordings · \(mins) minutes of you")
    }

    private func bookGroup(_ bookId: String?, _ items: [Takeaway]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bookTitle(bookId)).sectionLabel()
                Spacer()
                Button { playAll(items) } label: {
                    Text("Play all").font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                }.buttonStyle(.plain)
            }
            VStack(spacing: 10) {
                ForEach(items) { row($0) }
            }
        }
    }

    private func row(_ t: Takeaway) -> some View {
        let active = player.currentID == t.id
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { toggle(t) } label: {
                    ZStack {
                        Circle().fill(palette.glassProminent).frame(width: 42, height: 42)
                        Image(systemName: (active && player.isPlaying) ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(palette.brassValue)
                    }
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel(t.date)).font(BGFont.row).foregroundStyle(palette.ink(.strong))
                    if let transcript = t.transcript, !transcript.isEmpty {
                        Text(transcript).font(BGFont.aside(13)).foregroundStyle(palette.ink(.body)).lineLimit(1)
                    }
                }
                Spacer()
                Text(durationLabel(t.durationSec)).font(BGFont.mono(12)).foregroundStyle(palette.ink(.secondary))
            }
            if active {
                VStack(spacing: 6) {
                    WaveformView(levels: t.waveform ?? [], progress: player.progress, height: 24)
                        .frame(height: 24)
                    HStack {
                        Text(timeString(player.currentTime)).font(BGFont.mono(11)).foregroundStyle(palette.brassValue)
                        Spacer()
                        Text(timeString(t.durationSec)).font(BGFont.mono(11)).foregroundStyle(palette.ink(.secondary))
                    }
                }
            }
        }
        .padding(14)
        .glass(active ? .prominent : .quiet, cornerRadius: 18)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing recorded yet.").font(BGFont.serif(20, .medium)).foregroundStyle(palette.ink(.strong))
            Text("After a session, say one thing you'll remember.").font(BGFont.body).foregroundStyle(palette.ink(.secondary))
        }
        .padding(.top, 8)
    }

    // MARK: Actions

    private func toggle(_ t: Takeaway) {
        player.toggle(t, url: store.audioURL(for: t))
    }
    private func playAll(_ items: [Takeaway]) {
        if let first = items.first { toggle(first) }   // sequential auto-advance is a later refinement
    }

    // MARK: Labels

    private func bookTitle(_ bookId: String?) -> String {
        guard let bookId, let book = services.books.book(id: bookId) else { return String(localized: "Other") }
        return book.title
    }
    private func dayLabel(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE d MMM"; return df.string(from: date)
    }
    private func durationLabel(_ sec: Double) -> String { timeString(sec) }
    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
