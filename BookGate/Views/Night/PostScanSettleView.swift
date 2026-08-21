import SwiftUI

/// Post-scan settling (screen 4c). No countdown. Cover found, shield up, exactly one decision: read
/// now, or hear last time's takeaway first. A ~6-second beat, then the session begins on its own.
struct PostScanSettleView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var advance: Task<Void, Never>?
    @State private var player = AudioPlayer()
    /// True once the user has asked to hear last night's takeaway. The 6-second beat is cancelled
    /// for the duration — nobody wants the session to start over the top of their own voice.
    @State private var listening = false

    private var session: SessionCoordinator { services.session }
    private var book: Book? { services.books.currentReading }
    private var lastTakeaway: Takeaway? { services.takeaways.latest }
    private var length: Int { services.settings.effectiveTonightLength }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.32))
            VStack(spacing: 22) {
                Spacer()
                if let book {
                    BookCoverView(book: book, image: services.books.coverImage(for: book),
                                  width: 120, height: 178)
                }
                VStack(spacing: 6) {
                    Text("\(book?.title ?? "Your book") · Shield on").sectionLabel()
                    Text("Ready when you are.")
                        .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero))
                    Text("\(length) minutes, starting the moment you tap.")
                        .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                }
                Spacer()
                VStack(spacing: 12) {
                    if listening, let t = lastTakeaway {
                        nowPlaying(t)
                    }
                    Button("Start Reading") { begin() }
                        .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                    if let t = lastTakeaway, !listening {
                        // This used to start the session without playing anything — the one button
                        // on the screen that lied about what it did.
                        Button("Hear last time first") { hearLastTime(t) }
                            .buttonStyle(TextButtonStyle(ink: .secondary))
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 64)
            .padding(.bottom, 40)
        }
        .task {
            advance = Task {
                try? await Task.sleep(for: .seconds(6))
                if !Task.isCancelled && !listening { begin() }
            }
        }
        // When the recording runs out, settle back into the beat rather than sitting there.
        .onChange(of: player.currentID) { was, now in
            if listening, was != nil, now == nil { listening = false }
        }
        .onDisappear { advance?.cancel(); player.stop() }
    }

    /// A small, live row while last night's takeaway plays — the waveform fills, and the same tap
    /// stops it.
    private func nowPlaying(_ t: Takeaway) -> some View {
        Button { player.toggle(t, url: services.takeaways.audioURL(for: t)) } label: {
            HStack(spacing: 12) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.brassValue)
                    .frame(width: 24)
                WaveformView(levels: t.waveform ?? [], progress: player.progress, height: 22)
                    .frame(height: 22)
                Text(timeString(t.durationSec))
                    .font(BGFont.mono(11)).foregroundStyle(palette.ink(.secondary))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .glass(.quiet, cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Last night's takeaway")
    }

    private func hearLastTime(_ t: Takeaway) {
        advance?.cancel()
        listening = true
        player.toggle(t, url: services.takeaways.audioURL(for: t))
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func begin() {
        advance?.cancel()
        player.stop()
        session.startSession()
    }
}
