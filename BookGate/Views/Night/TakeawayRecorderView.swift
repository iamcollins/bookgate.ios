import SwiftUI

/// The takeaway recorder (part of screen 9). Idle → recording (live waveform) → review (play, scrub,
/// re-record, save). Optional every time; skipping never breaks the streak.
struct TakeawayRecorderView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette

    private enum Stage { case idle, recording, review }
    @State private var stage: Stage = .idle
    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()
    @State private var result: AudioRecorder.Result?
    @State private var micDenied = false

    private var session: SessionCoordinator { services.session }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.3))
            VStack(spacing: 22) {
                Spacer()
                Text("Takeaway").sectionLabel()
                Text(prompt)
                    .font(BGFont.serif(27, .medium))
                    .foregroundStyle(palette.ink(.hero))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer().frame(height: 8)
                stageContent
                Spacer()
                actions
            }
            .padding(.horizontal, 26)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .onDisappear { recorder.cancel(); player.stop() }
    }

    private var prompt: String {
        switch stage {
        case .idle:      return "What's one thing you want to remember?"
        case .recording: return "Listening…"
        case .review:    return "Keep this one?"
        }
    }

    @ViewBuilder private var stageContent: some View {
        switch stage {
        case .idle:
            if micDenied {
                Text("Enable the microphone in Settings to record, or skip.")
                    .font(BGFont.body).foregroundStyle(palette.ink(.secondary)).multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Text("Say it the way you'd say it to a friend.")
                        .font(BGFont.aside(14)).foregroundStyle(palette.ink(.body))
                    if let book = services.books.currentReading {
                        Text("Saving under \(book.title)")
                            .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    }
                }
            }
        case .recording:
            VStack(spacing: 14) {
                WaveformView(levels: recorder.levels, progress: 1, height: 40)
                    .frame(height: 40)
                Text(timeString(recorder.elapsed))
                    .font(BGFont.mono(15)).foregroundStyle(palette.ink(.body))
            }
        case .review:
            if let result {
                VStack(spacing: 14) {
                    WaveformView(levels: result.waveform, progress: player.currentID != nil ? player.progress : 0, height: 40)
                        .frame(height: 40)
                    Text("\(timeString(player.currentID != nil ? player.currentTime : 0)) / \(timeString(result.duration))")
                        .font(BGFont.mono(13)).foregroundStyle(palette.ink(.secondary))
                }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        switch stage {
        case .idle:
            VStack(spacing: 12) {
                Button("Start recording") { startRecording() }
                    .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                Button("Skip") { session.finishedTakeawayStep() }
                    .buttonStyle(TextButtonStyle(ink: .secondary))
            }
        case .recording:
            Button("Stop") { stopRecording() }
                .buttonStyle(GlassButtonStyle(minHeight: 56))
        case .review:
            VStack(spacing: 12) {
                Button(player.isPlaying ? "Pause" : "Play") { togglePlay() }
                    .buttonStyle(GlassButtonStyle(minHeight: 52))
                Button("Save Takeaway") { save() }
                    .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                Button("Re-record") { reRecord() }
                    .buttonStyle(TextButtonStyle(ink: .secondary))
            }
        }
    }

    // MARK: Actions

    private func startRecording() {
        Task {
            let ok = await AudioRecorder.requestPermission()
            if !ok { micDenied = true; return }
            recorder.start()
            stage = .recording
        }
    }

    private func stopRecording() {
        result = recorder.stop()
        stage = result == nil ? .idle : .review
    }

    private func togglePlay() {
        guard let result else { return }
        let url = TakeawayStore.audioDirectory.appendingPathComponent(result.file)
        let stub = Takeaway(id: UUID(), bookId: nil, date: .now, durationSec: result.duration, file: result.file, waveform: result.waveform)
        player.toggle(stub, url: url)
    }

    private func reRecord() {
        player.stop()
        if let result {
            try? FileManager.default.removeItem(at: TakeawayStore.audioDirectory.appendingPathComponent(result.file))
        }
        result = nil
        stage = .idle
    }

    private func save() {
        guard let result else { session.finishedTakeawayStep(); return }
        player.stop()
        services.takeaways.add(bookId: services.books.currentReading?.idString,
                               durationSec: result.duration,
                               file: result.file,
                               waveform: result.waveform)
        session.finishedTakeawayStep()
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
