import UIKit
import Observation

/// The library: the list of books plus the on-disk cover images. Metadata persists as one Codable
/// snapshot in UserDefaults; cover photos live on disk via `ImageStorage`. There is at most one
/// `reading` book at a time — the one the nightly session is bound to.
@MainActor @Observable
final class BookStore {

    private(set) var books: [Book] = []

    private let storage = ImageStorage()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private static let key = "bookgate.books.v1"

    // MARK: Derived shelves

    /// The single book currently being read (the nightly session's book).
    var currentReading: Book? { books.first { $0.status == .reading } }
    var nextUp: [Book] { books.filter { $0.status == .next } }
    var paused: [Book] { books.filter { $0.status == .paused } }
    var finished: [Book] { books.filter { $0.status == .finished } }

    func book(id: String) -> Book? { books.first { $0.idString == id } }

    // MARK: Mutations

    /// Add a book. If it's the first book, it becomes the `reading` one so the app always has a
    /// current book for the alarm/session.
    @discardableResult
    func add(title: String, author: String = "", coverFile: String? = nil,
             status: BookStatus? = nil) -> Book {
        let hasReading = currentReading != nil
        let resolved = status ?? (hasReading ? .next : .reading)
        let book = Book(title: title, author: author, status: resolved, coverFile: coverFile)
        books.append(book)
        save()
        return book
    }

    func update(_ book: Book) {
        guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[i] = book
        save()
    }

    /// Make `book` the current reading book, demoting any other reading book to `next`.
    func startReading(_ book: Book) {
        for i in books.indices where books[i].status == .reading && books[i].id != book.id {
            books[i].status = .next
        }
        guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[i].status = .reading
        if books[i].startedDate == nil { books[i].startedDate = .now }
        save()
    }

    func setStatus(_ book: Book, _ status: BookStatus) {
        guard let i = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[i].status = status
        if status == .finished { books[i].finishedDate = .now }
        save()
    }

    func delete(_ book: Book) {
        if let file = book.coverFile { storage.delete([file]); thumbnailCache.removeObject(forKey: file as NSString) }
        books.removeAll { $0.id == book.id }
        save()
    }

    /// Record a completed session for a book — increments its counts and stamps its start date.
    func recordSession(bookId: String, minutes: Int) {
        guard let i = books.firstIndex(where: { $0.idString == bookId }) else { return }
        books[i].sessionsRead += 1
        books[i].minutesRead += minutes
        if books[i].startedDate == nil { books[i].startedDate = .now }
        save()
    }

    /// Write a photographed cover JPEG to disk and attach it to a book. Returns the file name.
    @discardableResult
    func setCover(_ jpeg: Data, for book: Book) -> String? {
        let name = "cover-\(book.id.uuidString).jpg"
        guard storage.write(jpeg, name: name) else { return nil }
        thumbnailCache.removeObject(forKey: name as NSString)
        if let i = books.firstIndex(where: { $0.id == book.id }) {
            books[i].coverFile = name
            save()
        }
        return name
    }

    // MARK: Cover images

    func coverImage(for book: Book) -> UIImage? {
        guard let file = book.coverFile else { return nil }
        return storage.loadImage(file)
    }

    func coverThumbnail(for book: Book, maxPixel: CGFloat = 400) -> UIImage? {
        guard let file = book.coverFile else { return nil }
        if let cached = thumbnailCache.object(forKey: file as NSString) { return cached }
        guard let image = storage.thumbnail(file, maxPixel: maxPixel) else { return nil }
        thumbnailCache.setObject(image, forKey: file as NSString)
        return image
    }

    // MARK: Persistence

    private struct Snapshot: Codable { var books: [Book] }

    static func load() -> BookStore {
        let store = BookStore()
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return store }
        store.books = snap.books
        return store
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Snapshot(books: books)) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
