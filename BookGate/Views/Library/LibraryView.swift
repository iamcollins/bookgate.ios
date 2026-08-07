import SwiftUI

/// Library (screen 7a). A READING NOW card, then NEXT UP / PAUSED / FINISHED shelves. Takeaway
/// counts sit where page counts would in a tracker — that is the point.
struct LibraryView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var showAdd = false
    @State private var path: [Book] = []

    private var books: BookStore { services.books }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BGAmbientBackground()
                ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if let reading = books.currentReading {
                        NavigationLink(value: reading) { ReadingNowCard(book: reading) }
                            .buttonStyle(.plain)
                    }
                    shelf(title: "Next up", books: books.nextUp, showAddTile: true)
                    if !books.paused.isEmpty { pausedShelf }
                    if !books.finished.isEmpty { finishedShelf }
                    if books.books.isEmpty { emptyState }
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 120)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationDestination(for: Book.self) { BookDetailsView(bookID: $0.id) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["BOOKGATE_OPEN_BOOK"] == "1",
               path.isEmpty, let reading = books.currentReading {
                path = [reading]
            }
            #endif
        }
        .sheet(isPresented: $showAdd) {
            AddBookView().environment(services)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Library").font(BGFont.screenTitle).foregroundStyle(palette.ink(.hero))
            Spacer()
            Button { showAdd = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("Add").font(BGFont.ui(14, .semibold))
                }
                .foregroundStyle(palette.brassValue)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .glass(.card, cornerRadius: 15)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Reading Now card

    private struct ReadingNowCard: View {
        let book: Book
        @Environment(AppServices.self) private var services
        @Environment(\.bgPalette) private var palette
        var body: some View {
            HStack(spacing: 14) {
                BookCoverView(book: book, image: services.books.coverThumbnail(for: book),
                              width: 70, height: 104)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reading now").sectionLabel()
                    Text(book.title).font(BGFont.serif(20, .medium))
                        .foregroundStyle(palette.ink(.hero)).lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author).font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                    }
                    HStack(spacing: 12) {
                        countText(services.takeaways.count(forBook: book.idString), "takeaways")
                        countText(book.sessionsRead, "sessions")
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.ink(.secondary))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .glass(.card, cornerRadius: 24)
        }
        private func countText(_ n: Int, _ label: String) -> some View {
            HStack(spacing: 3) {
                Text("\(n)").font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                Text(label).font(BGFont.ui(13, .regular)).foregroundStyle(palette.ink(.secondary))
            }
        }
    }

    // MARK: Shelves

    private func shelf(title: String, books shelfBooks: [Book], showAddTile: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).sectionLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(shelfBooks) { book in
                        NavigationLink(value: book) {
                            coverTile(book, width: 84, height: 122)
                        }.buttonStyle(.plain)
                    }
                    if showAddTile { addTile }
                }
            }
        }
    }

    private func coverTile(_ book: Book, width: CGFloat, height: CGFloat, opacity: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(book: book, image: services.books.coverThumbnail(for: book),
                          width: width, height: height)
                .opacity(opacity)
            Text(book.title).font(BGFont.ui(11.5, .medium))
                .foregroundStyle(palette.ink(.body)).lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
    }

    private var addTile: some View {
        Button { showAdd = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 22, weight: .light))
                    .foregroundStyle(palette.ink(.secondary))
                Text("Add a book").font(BGFont.ui(11, .medium))
                    .foregroundStyle(palette.ink(.secondary)).multilineTextAlignment(.center)
            }
            .frame(width: 84, height: 122)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [5, 4]))
                    .foregroundStyle(palette.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    private var pausedShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paused").sectionLabel()
            VStack(spacing: 10) {
                ForEach(books.paused) { book in
                    NavigationLink(value: book) {
                        HStack(spacing: 12) {
                            BookCoverView(book: book, image: services.books.coverThumbnail(for: book),
                                          width: 40, height: 60)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title).font(BGFont.row).foregroundStyle(palette.ink(.strong)).lineLimit(1)
                                Text("Paused · \(services.takeaways.count(forBook: book.idString)) takeaways")
                                    .font(BGFont.caption).foregroundStyle(palette.ink(.secondary))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.ink(.secondary))
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var finishedShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finished").sectionLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(books.finished) { book in
                        NavigationLink(value: book) {
                            BookCoverView(book: book, image: services.books.coverThumbnail(for: book),
                                          width: 56, height: 76).opacity(0.72)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No books yet.").font(BGFont.serif(20, .medium)).foregroundStyle(palette.ink(.strong))
            Text("Add the book you're reading to begin.").font(BGFont.body).foregroundStyle(palette.ink(.secondary))
        }
        .padding(.top, 8)
    }
}
