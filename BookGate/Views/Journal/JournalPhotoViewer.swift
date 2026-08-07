import SwiftUI

/// Full-screen viewer for the nightly journal photos — swipe between nights, see the date, delete.
/// Always dark (a journal of lamplit nights). On-device only.
struct JournalPhotoViewer: View {
    let entries: [JournalEntry]
    let startIndex: Int
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var confirmDelete = false

    init(entries: [JournalEntry], startIndex: Int) {
        self.entries = entries
        self.startIndex = startIndex
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    Group {
                        if let img = services.journal.image(for: entry) {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            Color(hex: 0x100C09)
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                    }
                    Spacer()
                    Button { confirmDelete = true } label: {
                        Image(systemName: "trash").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85)).frame(width: 44, height: 44)
                    }
                }
                Spacer()
                if entries.indices.contains(index) {
                    Text(longDate(entries[index].date))
                        .font(BGFont.aside(15)).foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 44)
        }
        .confirmationDialog("Delete this night's photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete photo", role: .destructive) { deleteCurrent() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deleteCurrent() {
        guard entries.indices.contains(index) else { return }
        services.journal.delete(entries[index])
        dismiss()   // list changed; simplest is to close and reopen from the refreshed strip
    }

    private func longDate(_ date: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .full; return df.string(from: date)
    }
}
