import AVFoundation
import Observation

/// Plays back a takeaway with observable progress, so a row can render its waveform filling as it
/// plays. One shared player per screen; playing a new item stops the previous one.
@MainActor @Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {

    /// The id of the item currently loaded (nil when stopped), so rows know which one is active.
    private(set) var currentID: UUID?
    private(set) var isPlaying = false
    private(set) var progress: Double = 0     // 0…1
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// Toggle play/pause for `takeaway`. Loads it if a different item is active.
    func toggle(_ takeaway: Takeaway, url: URL) {
        if currentID == takeaway.id {
            isPlaying ? pause() : resume()
        } else {
            load(takeaway, url: url)
            resume()
        }
    }

    private func load(_ takeaway: Takeaway, url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            player = p
            currentID = takeaway.id
            duration = p.duration
            progress = 0; currentTime = 0
        } catch {
            currentID = nil
        }
    }

    func resume() {
        guard let p = player else { return }
        p.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        player?.pause(); isPlaying = false
        timer?.invalidate(); timer = nil
    }

    /// Scrub to a 0…1 position.
    func seek(to fraction: Double) {
        guard let p = player else { return }
        let clamped = max(0, min(1, fraction))
        p.currentTime = clamped * p.duration
        progress = clamped
        currentTime = p.currentTime
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop(); player = nil
        isPlaying = false; currentID = nil; progress = 0; currentTime = 0; duration = 0
    }

    private func tick() {
        guard let p = player else { return }
        currentTime = p.currentTime
        duration = p.duration
        progress = p.duration > 0 ? p.currentTime / p.duration : 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.timer?.invalidate(); self.timer = nil
        }
    }
}
