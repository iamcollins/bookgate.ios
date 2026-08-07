import Vision
import AVFoundation
import Observation

/// The nightly gate engine: prove it's you *and* your book. Runs the front camera and looks for a
/// **face + a hand + a book** together in frame, sustained for a few frames, then captures that
/// frame as the night's journal photo. Designed for low light (9pm, lamplit) and tuned lenient —
/// present enough to require real engagement, not so strict it frustrates. A **manual fallback** is
/// always available (and is the only path on the Simulator, which has no camera).
///
/// Frame flow mirrors Thrise's camera engines: `CameraSession.onFrame` → `nonisolated process`
/// (Vision off the main actor, serialized on the camera queue) → a `@MainActor` hop to publish the
/// hint state and fire the one-shot capture.
@MainActor @Observable
final class NightGateDetector {

    // UI-facing hint state
    private(set) var faceSeen = false
    private(set) var handSeen = false
    private(set) var bookSeen = false
    /// 0→1 toward a confirmed detection (drives the frame's fill/animation).
    private(set) var progress: Double = 0
    private(set) var finished = false

    /// Fired once with the captured JPEG (nil if the manual fallback fired before any frame).
    var onCapture: ((Data?) -> Void)?

    private let camera = CameraSession(position: .front)
    private let face = FaceDetector()
    private let scene = SceneClassifier(minConfidence: 0.15)   // lenient for low light / partial books

    /// The underlying capture session, for `CameraPreview`.
    var captureSession: AVCaptureSession { camera.session }

    // Off-main state, guarded by `lock` (process runs serially on the camera queue).
    private let lock = NSLock()
    @ObservationIgnored nonisolated(unsafe) private var streak = 0
    @ObservationIgnored nonisolated(unsafe) private var bookEver = false
    @ObservationIgnored nonisolated(unsafe) private var lastProcess = Date.distantPast
    @ObservationIgnored nonisolated(unsafe) private var didCapture = false
    @ObservationIgnored nonisolated(unsafe) private var manualRequested = false

    private let requiredHits = 6
    private let minInterval = 0.28   // ~3.5 fps

    var cameraAvailable: Bool { CameraAccess.isAuthorized }

    func start() {
        camera.onFrame = { [weak self] buffer in self?.process(buffer) }
        camera.start()
    }

    func stop() {
        camera.stop()
        camera.onFrame = nil
    }

    /// The always-visible manual fallback. Captures the next frame if the camera is running,
    /// otherwise completes with no photo.
    func requestManualCapture() {
        lock.lock(); manualRequested = true; let running = !didCapture; lock.unlock()
        if !running || !cameraAvailable {
            fireCapture(nil)
        }
        // If a camera is running, the next `process` frame will encode + fire.
    }

    private func fireCapture(_ data: Data?) {
        guard !finished else { return }
        finished = true
        onCapture?(data)
    }

    // MARK: Frame processing (camera queue)

    nonisolated func process(_ buffer: CVPixelBuffer) {
        lock.lock()
        if didCapture { lock.unlock(); return }
        let now = Date()
        let manual = manualRequested
        if !manual, now.timeIntervalSince(lastProcess) < minInterval { lock.unlock(); return }
        lastProcess = now
        lock.unlock()

        // Manual fallback: capture this frame immediately, regardless of detection.
        if manual {
            let jpeg = ImageStorage.jpeg(from: buffer, quality: 0.85)
            lock.lock(); didCapture = true; lock.unlock()
            Task { @MainActor [weak self] in self?.fireCapture(jpeg) }
            return
        }

        let hasFace = face.hasFace(in: buffer)
        let hasHand = Self.detectHand(in: buffer)
        let labels = scene.classify(in: buffer)
        let hasBook = labels.contains { Self.isBookLabel($0.identifier) }

        lock.lock()
        if hasBook { bookEver = true }
        let bookOK = bookEver
        if hasFace && hasHand { streak += 1 } else { streak = max(0, streak - 1) }
        let s = streak
        var captured: Data?
        if hasFace && hasHand && bookOK && s >= requiredHits {
            didCapture = true
            captured = ImageStorage.jpeg(from: buffer, quality: 0.85)
        }
        lock.unlock()

        let p = min(1, Double(s) / Double(requiredHits))
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.faceSeen = hasFace
            self.handSeen = hasHand
            self.bookSeen = bookOK
            self.progress = p
            if let captured { self.fireCapture(captured) }
        }
    }

    // MARK: Vision helpers

    /// A hand is present if VNDetectHumanHandPoseRequest finds at least one hand with a reasonable
    /// average confidence. A fresh request per call keeps this free of shared mutable state.
    private nonisolated static func detectHand(in buffer: CVPixelBuffer) -> Bool {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored, options: [:])
        try? handler.perform([request])
        guard let hand = request.results?.first else { return false }
        // A few high-confidence points is enough — we only need "a hand is in frame".
        if let points = try? hand.recognizedPoints(.all) {
            let confident = points.values.filter { $0.confidence > 0.3 }
            return confident.count >= 3
        }
        return true
    }

    /// Generic scene labels that read as "a book/printed matter is in frame". Lenient by design.
    private nonisolated static func isBookLabel(_ id: String) -> Bool {
        let needles = ["book", "notebook", "magazine", "paperback", "hardback",
                       "menu", "document", "paper", "envelope", "comic"]
        let lower = id.lowercased()
        return needles.contains { lower.contains($0) }
    }
}
