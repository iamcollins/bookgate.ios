import SwiftUI
import Vision
import AVFoundation

/// Full-screen back-camera capture for a book cover. On the shutter it grabs one frame as the cover
/// image and best-effort OCRs the largest text as a title suggestion. On the Simulator (no camera)
/// the shutter is disabled and the user types the title instead.
struct CoverCaptureView: View {
    /// (jpeg, image, suggestedTitle)
    var onResult: (Data, UIImage, String?) -> Void

    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var controller = CoverCaptureController()
    @State private var authDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if authDenied {
                CameraUnavailableView(message: String(localized: "Enable camera access to photograph a cover, or go back and type the title."))
            } else {
                CameraPreview(session: controller.camera.session).ignoresSafeArea()
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                Spacer()
                Text("Fill the frame with the cover")
                    .font(BGFont.ui(14, .medium)).foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 16)
                Button { controller.capture() } label: {
                    Circle().fill(.white).frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 4).padding(-6))
                }
                .disabled(authDenied)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
        }
        .task {
            let status = await CameraAccess.request()
            authDenied = (status == .denied || status == .restricted)
            controller.onResult = { jpeg, img, ocr in
                onResult(jpeg, img, ocr)
                dismiss()
            }
            controller.start()
        }
        .onDisappear { controller.stop() }
    }
}

@MainActor @Observable
final class CoverCaptureController {
    let camera = CameraSession(position: .back)
    var onResult: ((Data, UIImage, String?) -> Void)?

    private let lock = NSLock()
    @ObservationIgnored nonisolated(unsafe) private var wantCapture = false
    @ObservationIgnored nonisolated(unsafe) private var done = false

    func start() {
        camera.onFrame = { [weak self] buffer in self?.handle(buffer) }
        camera.start()
    }
    func stop() { camera.stop(); camera.onFrame = nil }

    func capture() { lock.lock(); wantCapture = true; lock.unlock() }

    nonisolated func handle(_ buffer: CVPixelBuffer) {
        lock.lock()
        guard wantCapture, !done else { lock.unlock(); return }
        wantCapture = false; done = true
        lock.unlock()

        guard let jpeg = ImageStorage.jpeg(from: buffer, quality: 0.9),
              let image = UIImage(data: jpeg) else { return }
        let title = Self.ocrTitle(from: buffer)
        Task { @MainActor [weak self] in self?.onResult?(jpeg, image, title) }
    }

    /// Best-effort: the largest recognised text line, which is usually the title.
    private nonisolated static func ocrTitle(from buffer: CVPixelBuffer) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let results = request.results, !results.isEmpty else { return nil }
        // Pick the observation with the tallest bounding box (largest type = likely the title).
        let best = results.max { $0.boundingBox.height < $1.boundingBox.height }
        return best?.topCandidates(1).first?.string
    }
}
