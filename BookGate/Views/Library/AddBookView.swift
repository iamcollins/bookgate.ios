import SwiftUI

/// Add a book. Photograph the **cover** with the back camera (optionally OCR the title), or type it
/// in. No barcode, no ISBN, no network — fully on-device.
struct AddBookView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var coverJPEG: Data?
    @State private var coverImage: UIImage?
    @State private var showCapture = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                BGAmbientBackground(showGlow: false)
                ScrollView {
                    VStack(spacing: 20) {
                        coverArea
                        field("Title", text: $title)
                        field("Author", text: $author)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(palette.ink(.secondary))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.tint(palette.brassValue).disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCapture) {
                CoverCaptureView { jpeg, image, ocrTitle in
                    coverJPEG = jpeg
                    coverImage = image
                    if title.isEmpty, let ocrTitle, !ocrTitle.isEmpty { title = ocrTitle }
                }
            }
        }
    }

    private var coverArea: some View {
        Button { showCapture = true } label: {
            Group {
                if let coverImage {
                    Image(uiImage: coverImage).resizable().scaledToFill()
                        .frame(width: 140, height: 206).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill").font(.system(size: 24, weight: .light))
                            .foregroundStyle(palette.ink(.secondary))
                        Text("Photograph the cover").font(BGFont.ui(13, .medium))
                            .foregroundStyle(palette.ink(.secondary))
                    }
                    .frame(width: 140, height: 206)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [5, 4]))
                            .foregroundStyle(palette.hairline)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).sectionLabel()
            TextField("", text: text)
                .font(BGFont.row)
                .foregroundStyle(palette.ink(.hero))
                .padding(14)
                .glass(.card, cornerRadius: 16)
        }
    }

    private func save() {
        let book = services.books.add(title: title.trimmingCharacters(in: .whitespaces),
                                      author: author.trimmingCharacters(in: .whitespaces))
        if let coverJPEG { services.books.setCover(coverJPEG, for: book) }
        dismiss()
    }
}
