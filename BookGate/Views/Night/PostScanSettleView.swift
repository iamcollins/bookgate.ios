import SwiftUI

/// Post-scan settling (screen 4c). No countdown. Cover found, shield up, exactly one decision: read
/// now, or hear last time's takeaway first. A ~6-second beat, then the session begins on its own.
struct PostScanSettleView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var advance: Task<Void, Never>?

    private var session: SessionCoordinator { services.session }
    private var book: Book? { services.books.currentReading }
    private var lastTakeaway: Takeaway? { services.takeaways.latest }
    private var length: Int { services.settings.effectiveTonightLength }

    var body: some View {
        ZStack {
            BGAmbientBackground(center: UnitPoint(x: 0.5, y: 0.32))
            VStack(spacing: 22) {
                Spacer()
                if let book {
                    BookCoverView(book: book, image: services.books.coverImage(for: book),
                                  width: 120, height: 178)
                }
                VStack(spacing: 6) {
                    Text("\(book?.title ?? "Your book") · Shield on").sectionLabel()
                    Text("Ready when you are.")
                        .font(BGFont.serif(27, .medium)).foregroundStyle(palette.ink(.hero))
                    Text("\(length) minutes, starting the moment you tap.")
                        .font(BGFont.aside(15)).foregroundStyle(palette.ink(.body))
                }
                Spacer()
                VStack(spacing: 12) {
                    Button("Start Reading") { begin() }
                        .buttonStyle(PrimaryActionButtonStyle(minHeight: 56))
                    if lastTakeaway != nil {
                        Button("Hear last time first") { begin() }
                            .buttonStyle(TextButtonStyle(ink: .secondary))
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 64)
            .padding(.bottom, 40)
        }
        .task {
            advance = Task {
                try? await Task.sleep(for: .seconds(6))
                if !Task.isCancelled { begin() }
            }
        }
        .onDisappear { advance?.cancel() }
    }

    private func begin() {
        advance?.cancel()
        session.startSession()
    }
}
