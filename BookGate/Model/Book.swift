import SwiftUI

/// Where a book sits in the reading life-cycle. Drives Library's shelves.
enum BookStatus: String, Codable, CaseIterable {
    case reading    // the one book the nightly session is bound to
    case next       // NEXT UP shelf
    case paused     // PAUSED shelf
    case finished   // FINISHED shelf
}

/// A book in the library. Covers are **photographed with the back camera** (`coverFile`, stored on
/// disk); when absent, a typographic placeholder is drawn from `coverSeed`. No barcode, no ISBN, no
/// network — fully on-device. Session/read counts are incremented at session completion; takeaway
/// counts are derived from the takeaway archive.
struct Book: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var status: BookStatus
    var addedDate: Date
    /// First night a session ran for this book — "Since 12 July".
    var startedDate: Date?
    var finishedDate: Date?
    /// Cover photo file name on disk (ImageStorage); nil → placeholder cover.
    var coverFile: String?
    /// Deterministic seed for the placeholder cover gradient/typography.
    var coverSeed: Int
    /// Completed sessions and total minutes read for this book.
    var sessionsRead: Int
    var minutesRead: Int

    init(id: UUID = UUID(), title: String, author: String = "",
         status: BookStatus = .next, addedDate: Date = .now,
         startedDate: Date? = nil, finishedDate: Date? = nil,
         coverFile: String? = nil, coverSeed: Int = Int.random(in: 0..<10_000),
         sessionsRead: Int = 0, minutesRead: Int = 0) {
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.addedDate = addedDate
        self.startedDate = startedDate
        self.finishedDate = finishedDate
        self.coverFile = coverFile
        self.coverSeed = coverSeed
        self.sessionsRead = sessionsRead
        self.minutesRead = minutesRead
    }

    var idString: String { id.uuidString }
}
