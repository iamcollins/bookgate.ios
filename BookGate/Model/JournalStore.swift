import UIKit
import Observation

/// One night's reading-journal photo: the "me + my book" front-camera still captured when the
/// nightly gate succeeds. Stored as a JPEG on disk (via `ImageStorage`) and referenced by name.
/// Tagged to the book being read (`bookId`) and dated, so the journal groups by book and by night.
///
/// Privacy: this still shows the user's face and is stored **on-device only, never uploaded** —
/// consent is made explicit in onboarding/permissions.
struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// `Book.id.uuidString` of the book read that night; nil if captured without a book.
    var bookId: String?
    /// Stored JPEG file name on disk.
    var file: String
}

/// The reading journal: a newest-first list of nightly photos. Metadata persists as one Codable
/// snapshot in UserDefaults; the images live on disk via `ImageStorage` (same pattern as Thrise's
/// gallery). Bounded by `maxItems`, pruning older entries *and their files*.
@MainActor @Observable
final class JournalStore {

    private(set) var entries: [JournalEntry] = []

    private let storage = ImageStorage()
    /// Decoded grid thumbnails, keyed by file name — keeps scrolling smooth.
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private static let thumbnailMaxPixel: CGFloat = 500
    private static let key = "bookgate.journal.v1"
    /// Generous cap (~2 years of nightly photos) so the journal persists but disk can't grow
    /// without bound.
    private static let maxItems = 800

    // MARK: Adding

    /// Save tonight's journal still. Writes the JPEG to disk and records the entry; returns it (for
    /// the complete screen) or nil if it couldn't be written.
    @discardableResult
    func addPhoto(_ jpeg: Data, bookId: String?, now: Date = .now) -> JournalEntry? {
        let id = UUID()
        let name = "\(id.uuidString).jpg"
        guard storage.write(jpeg, name: name) else { return nil }
        let entry = JournalEntry(id: id, date: now, bookId: bookId, file: name)
        entries.insert(entry, at: 0)
        prune()
        save()
        return entry
    }

    // MARK: Querying

    /// Newest-first entries for one book.
    func entries(forBook bookId: String) -> [JournalEntry] {
        entries.filter { $0.bookId == bookId }
    }

    /// The most recent journal photo overall (for a "last night" thumbnail on Today).
    var latest: JournalEntry? { entries.first }

    // MARK: Removing

    func delete(_ entry: JournalEntry) {
        storage.delete([entry.file])
        thumbnailCache.removeObject(forKey: entry.file as NSString)
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func prune() {
        guard entries.count > Self.maxItems else { return }
        for dropped in entries[Self.maxItems...] { storage.delete([dropped.file]) }
        entries = Array(entries.prefix(Self.maxItems))
    }

    // MARK: Reading images

    func image(for entry: JournalEntry) -> UIImage? {
        storage.loadImage(entry.file)
    }

    /// Downsampled, cached thumbnail so scrolling never re-decodes a full-res image off disk.
    func thumbnail(for entry: JournalEntry) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: entry.file as NSString) { return cached }
        guard let image = storage.thumbnail(entry.file, maxPixel: Self.thumbnailMaxPixel) else { return nil }
        thumbnailCache.setObject(image, forKey: entry.file as NSString)
        return image
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var entries: [JournalEntry] }

    static func load() -> JournalStore {
        let store = JournalStore()
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return store }
        // Reconcile against disk: drop entries whose file went missing, so the journal never shows
        // blanks and counts stay honest.
        store.entries = snap.entries.filter { store.storage.exists($0.file) }
        return store
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Snapshot(entries: entries)) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
