import SwiftUI

/// A horizontal strip of a book's nightly "me + my book" journal photos, shown on Book details.
/// Tapping opens the full-screen viewer. Hidden when the book has no photos yet.
struct JournalPhotoStrip: View {
    let bookID: String
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var viewerIndex: Int?

    private var entries: [JournalEntry] { services.journal.entries(forBook: bookID) }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nights read").sectionLabel()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            thumb(entry, index: index)
                        }
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { viewerIndex.map { IndexBox(id: $0) } },
                set: { viewerIndex = $0?.id }
            )) { box in
                JournalPhotoViewer(entries: entries, startIndex: box.id).environment(services)
            }
        }
    }

    private func thumb(_ entry: JournalEntry, index: Int) -> some View {
        Button { viewerIndex = index } label: {
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let img = services.journal.thumbnail(for: entry) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        palette.recess
                    }
                }
                .frame(width: 76, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(palette.hairline, lineWidth: 1))
                Text(shortDate(entry.date)).font(BGFont.ui(10.5, .medium)).foregroundStyle(palette.ink(.secondary))
            }
        }
        .buttonStyle(.plain)
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "d MMM"; return df.string(from: date)
    }
}

/// Identifiable index wrapper so `fullScreenCover(item:)` can carry the start index.
private struct IndexBox: Identifiable { let id: Int }
