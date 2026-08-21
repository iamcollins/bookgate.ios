import AVFoundation
import Observation

/// Records a spoken takeaway to an m4a file, metering the level for a live waveform. On stop it
/// returns the file name, duration, and a downsampled level array to store for playback rendering.
@MainActor @Observable
final class AudioRecorder {

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// Live normalized levels (0…1), newest last — drives the recording waveform.
    private(set) var levels: [Float] = []

    /// The last finished take. The recorder stops *itself* at the cap, from a timer the screen
    /// does not own, so the take has to be held here — otherwise a recording that ran to the cap
    /// was thrown away at the exact moment someone had the most to say.
    private(set) var lastResult: Result?

    private var recorder: AVAudioRecorder?
    private var fileName: String?
    private var meterTimer: Timer?
    /// Hard cap. A takeaway is usually well under a minute, but the cap must never be the thing
    /// that cuts someone off mid-thought — five minutes is long enough to finish any thought and
    /// still keeps a night's file small (~1.2 MB at this bitrate).
    static let maxSeconds: TimeInterval = 300
    private var maxLevels: Int { Int(Self.maxSeconds / 0.05) }

    /// Ask for microphone permission (one-time system prompt).
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
    }

    func start() {
        let (url, name) = TakeawayStore.newAudioFile()
        fileName = name
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec
            isRecording = true
            elapsed = 0
            levels = []
            lastResult = nil
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            isRecording = false
        }
    }

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        let power = rec.averagePower(forChannel: 0)          // dB, ~ -160…0
        let norm = max(0, min(1, (power + 55) / 55))         // map ~-55dB…0dB → 0…1
        levels.append(norm)
        if levels.count > maxLevels { levels.removeFirst(levels.count - maxLevels) }
        elapsed = rec.currentTime
        if elapsed >= Self.maxSeconds { _ = stop() }   // the take is kept in `lastResult`
    }

    /// Stop and return the result, or nil if nothing usable was recorded.
    struct Result { let file: String; let duration: TimeInterval; let waveform: [Float] }

    @discardableResult
    func stop() -> Result? {
        meterTimer?.invalidate(); meterTimer = nil
        guard let rec = recorder, let name = fileName else { isRecording = false; return nil }
        let duration = rec.currentTime
        rec.stop()
        recorder = nil
        isRecording = false
        // Hand ownership of the file to the caller. Leaving `fileName` set meant a later
        // `cancel()` — which the recorder screen runs on disappear — deleted the very file that
        // had just been saved, so every takeaway lost its audio and vanished on next launch.
        fileName = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard duration > 0.4 else {
            // Too short to be a takeaway — clean the stub file up rather than orphan it on disk.
            try? FileManager.default.removeItem(at: TakeawayStore.audioDirectory.appendingPathComponent(name))
            lastResult = nil
            return nil
        }
        let take = Result(file: name, duration: duration, waveform: Self.downsample(levels, to: 48))
        lastResult = take
        return take
    }

    func cancel() {
        meterTimer?.invalidate(); meterTimer = nil
        if let name = fileName {
            try? FileManager.default.removeItem(at: TakeawayStore.audioDirectory.appendingPathComponent(name))
        }
        recorder?.stop(); recorder = nil; fileName = nil; lastResult = nil
        isRecording = false; levels = []; elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Reduce a long level stream to `count` bars by averaging buckets.
    static func downsample(_ input: [Float], to count: Int) -> [Float] {
        guard input.count > count, count > 0 else { return input }
        let bucket = Double(input.count) / Double(count)
        return (0..<count).map { i in
            let lo = Int(Double(i) * bucket), hi = min(input.count, Int(Double(i + 1) * bucket))
            guard hi > lo else { return 0 }
            return input[lo..<hi].reduce(0, +) / Float(hi - lo)
        }
    }
}
