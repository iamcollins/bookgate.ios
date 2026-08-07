import SwiftUI

/// A book cover at any size. Shows the photographed cover when present; otherwise a typographic
/// placeholder — a warm gradient rectangle with a spine line and the title, matching the handoff's
/// placeholder covers. Cover radius is the real-spine `3 / 7 / 7 / 3` (small on the spine edge).
///
/// Covers are objects, not UI — they are **theme-independent** (never remapped by light/dark).
struct BookCoverView: View {
    let book: Book
    /// Pre-loaded photographed cover, if any (caller loads via `BookStore`).
    var image: UIImage?
    var width: CGFloat
    var height: CGFloat

    private var seedPalette: [Color] {
        // A small pool of warm book-cloth gradients, chosen deterministically by the seed.
        let palettes: [[UInt32]] = [
            [0x6D5340, 0x8A6A4E, 0x5D4635],
            [0x4A3B52, 0x6A5A78, 0x39304A],
            [0x3E4A3B, 0x5A6A50, 0x2E3A30],
            [0x52403B, 0x785A50, 0x3A302E],
            [0x3B4652, 0x506578, 0x2E3540],
            [0x5A4632, 0x8A6A44, 0x463522],
        ]
        return palettes[book.coverSeed % palettes.count].map { Color(hex: $0) }
    }

    private var coverShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3,
                               bottomTrailingRadius: 7, topTrailingRadius: 7,
                               style: .continuous)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(coverShape)
        .overlay(coverShape.strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.8), radius: 16, x: 0, y: 12)
        .accessibilityLabel(Text(book.title.isEmpty ? "Book cover" : book.title))
    }

    private var placeholder: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: seedPalette,
                           startPoint: UnitPoint(x: 0.15, y: 0.0),
                           endPoint: UnitPoint(x: 0.85, y: 1.0))
            // Spine line near the left edge.
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 1.5)
                .padding(.leading, max(6, width * 0.06))
            // Title, scaled to the cover.
            Text(book.title.isEmpty ? "Untitled" : book.title)
                .font(.custom(BGFont.serifFamily, size: max(9, width * 0.13)).weight(.medium))
                .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.92))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, width * 0.14)
                .padding(.top, height * 0.16)
        }
    }
}
