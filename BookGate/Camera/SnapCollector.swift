import CoreVideo
import Foundation

/// Gathers a few candid front-camera stills during a wake challenge — spaced out
/// and capped — for the morning gallery. The challenge decides *when* the subject
/// is well-framed and calls `capture` from its camera-frame queue; this owns the
/// cadence, the cap, and the JPEG encoding. Frame-queue safe.
///
/// Shared by Move Around (face-in-frame) and Pushups (body-in-frame) so both
/// produce keepsakes the same way. Stills are held as JPEG data and handed back
/// via the challenge's `producedArtifact` on completion — on-device only.
final class SnapCollector: @unchecked Sendable {

    private let maxSnaps: Int
    private let interval: TimeInterval

    private let lock = NSLock()
    private var snaps: [Data] = []            // guarded by `lock`
    private var lastAt = Date.distantPast     // touched only on the capture queue
    private var count = 0                      // touched only on the capture queue

    init(maxSnaps: Int = 4, interval: TimeInterval = 10) {
        self.maxSnaps = maxSnaps
        self.interval = interval
    }

    /// Grab a still from this frame if the cap and spacing allow. Call only when
    /// the subject is well-framed; runs on the camera frame queue.
    func capture(_ pixelBuffer: CVPixelBuffer, now: Date = Date()) {
        guard count < maxSnaps,
              now.timeIntervalSince(lastAt) >= interval,
              let data = ImageStorage.jpeg(from: pixelBuffer) else { return }
        lastAt = now
        count += 1
        lock.lock(); snaps.append(data); lock.unlock()
    }

    /// The stills gathered so far (oldest-first).
    var captured: [Data] {
        lock.lock(); defer { lock.unlock() }
        return snaps
    }
}
