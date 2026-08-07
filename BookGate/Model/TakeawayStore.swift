import Foundation
import Observation

/// One spoken takeaway: a ~30-second recording tied to a book and a night. Audio lives on disk in
/// `Documents/Takeaways/`; metadata persists as one Codable snapshot. On-device only, never uploaded.
struct Takeaway: Codable, Identifiable, Equatable {
    let id: UUID
    var bookId: String?
    let date: Date
    var durationSec: Double
    /// Audio file name in the takeaways directory.
    var file: String
    /// Optional on-device transcript (future; from Speech).
    var transcript: String?
    /// Downsampled normalized levels (0…1) captured while recording, for the playback waveform.
    var waveform: [Float]?
}

/// The takeaway archive: newest-first, grouped per book by the UI. The recorder (task #8) writes
/// audio here; Book details and the Takeaways tab read it.
@MainActor @Observable
final class TakeawayStore {

    private(set) var takeaways: [Takeaway] = []

    private static let key = "bookgate.takeaways.v1"
    private static let dirName = "Takeaways"

    /// Directory for takeaway audio files (created on demand).
    static var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(dirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func audioURL(for takeaway: Takeaway) -> URL {
        Self.audioDirectory.appendingPathComponent(takeaway.file)
    }

    /// A fresh file URL + name for the recorder to write into.
    static func newAudioFile() -> (url: URL, name: String) {
        let name = "\(UUID().uuidString).m4a"
        return (audioDirectory.appendingPathComponent(name), name)
    }

    // MARK: Query

    var totalCount: Int { takeaways.count }
    var totalSeconds: Double { takeaways.reduce(0) { $0 + $1.durationSec } }

    func takeaways(forBook bookId: String) -> [Takeaway] {
        takeaways.filter { $0.bookId == bookId }
    }
    func count(forBook bookId: String) -> Int {
        takeaways.reduce(0) { $0 + ($1.bookId == bookId ? 1 : 0) }
    }
    var latest: Takeaway? { takeaways.first }

    /// Newest-first, grouped by book id (preserving newest-first order of first appearance).
    func groupedByBook() -> [(bookId: String?, items: [Takeaway])] {
        var order: [String] = []
        var groups: [String: [Takeaway]] = [:]
        for t in takeaways {
            let key = t.bookId ?? "—"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(t)
        }
        return order.map { ($0 == "—" ? nil : $0, groups[$0] ?? []) }
    }

    // MARK: Mutations

    @discardableResult
    func add(bookId: String?, date: Date = .now, durationSec: Double, file: String,
             transcript: String? = nil, waveform: [Float]? = nil) -> Takeaway {
        let t = Takeaway(id: UUID(), bookId: bookId, date: date, durationSec: durationSec,
                         file: file, transcript: transcript, waveform: waveform)
        takeaways.insert(t, at: 0)
        save()
        return t
    }

    func delete(_ takeaway: Takeaway) {
        try? FileManager.default.removeItem(at: audioURL(for: takeaway))
        takeaways.removeAll { $0.id == takeaway.id }
        save()
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var takeaways: [Takeaway] }

    static func load() -> TakeawayStore {
        let store = TakeawayStore()
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return store }
        // Keep only entries whose audio still exists.
        store.takeaways = snap.takeaways.filter {
            FileManager.default.fileExists(atPath: store.audioURL(for: $0).path)
        }
        return store
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Snapshot(takeaways: takeaways)) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
