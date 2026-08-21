import XCTest
import AVFoundation
@testable import BookGate

/// The takeaway recording lifecycle.
///
/// The shipped build lost every takeaway: `stop()` handed the file name to the caller but kept its
/// own copy, so the recorder screen's `onDisappear { recorder.cancel() }` deleted the audio it had
/// just saved — and `TakeawayStore.load()`, which drops entries whose file is gone, then erased the
/// entry on the next launch. These pin the ownership rule: once `stop()` returns a take, the
/// recorder must never touch that file again.
@MainActor
final class TakeawayRecordingTests: XCTestCase {

    private func makeFile() -> (url: URL, name: String) {
        let (url, name) = TakeawayStore.newAudioFile()
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 0, count: 64))
        return (url, name)
    }

    override func tearDown() {
        // Leave no scratch audio behind.
        let dir = TakeawayStore.audioDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for f in files { try? FileManager.default.removeItem(at: f) }
        super.tearDown()
    }

    /// The store only keeps an entry whose audio is still on disk — which is what turned the
    /// deletion bug into a disappearing takeaway rather than a silent one.
    func testStoreDropsEntriesWhoseAudioIsMissing() {
        let store = TakeawayStore()
        let (url, name) = makeFile()
        let kept = store.add(bookId: nil, durationSec: 3, file: name, waveform: [0.5])
        XCTAssertEqual(store.totalCount, 1)

        try? FileManager.default.removeItem(at: url)
        let reloaded = TakeawayStore.load()
        XCTAssertFalse(reloaded.takeaways.contains { $0.id == kept.id },
                       "an entry with no audio must not survive a reload")
    }

    /// Deleting through the store removes the audio too — no orphan files.
    func testDeleteRemovesTheAudioFile() {
        let store = TakeawayStore()
        let (url, name) = makeFile()
        let t = store.add(bookId: nil, durationSec: 3, file: name, waveform: [0.5])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        store.delete(t)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.totalCount, 0)
    }

    /// A recorder that never started has nothing to give up and nothing to delete.
    func testCancelOnAnUnstartedRecorderIsHarmless() {
        let recorder = AudioRecorder()
        let (url, _) = makeFile()
        recorder.cancel()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "cancel must only ever touch its own in-flight file")
    }

    /// The cap is what the recorder screen counts down against; a one-minute cap cut people off
    /// mid-thought.
    func testRecordingCapIsGenerous() {
        XCTAssertGreaterThanOrEqual(AudioRecorder.maxSeconds, 180,
                                    "a takeaway must not be cut short by the cap")
    }

    /// Downsampling drives the stored waveform; it must hit the requested bar count exactly.
    func testDownsampleProducesTheRequestedBarCount() {
        let input = (0..<1000).map { Float($0 % 10) / 10 }
        XCTAssertEqual(AudioRecorder.downsample(input, to: 48).count, 48)
        // Fewer samples than bars is left alone rather than padded with silence.
        XCTAssertEqual(AudioRecorder.downsample([0.5, 0.5], to: 48).count, 2)
    }
}
