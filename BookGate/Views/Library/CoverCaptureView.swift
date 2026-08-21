import SwiftUI
import Vision
import AVFoundation

/// Full-screen back-camera capture for a book cover. The shutter takes a real photograph and
/// best-effort OCRs the largest text as a title suggestion. On the Simulator (no camera) the
/// shutter is disabled and the user types the title instead.
///
/// The shutter reports itself while it works: it becomes a spinner and stops accepting taps. A
/// photograph in a dim room is not instant — the exposure is longer, and the system may fuse
/// several frames — and with the button sitting perfectly still through it, the wait read as a
/// dead control rather than as a camera working. No flash and no viewfinder furniture beyond
/// that; this is a scanner for a cover, not a camera app.
struct CoverCaptureView: View {
    /// (jpeg, image, suggestedTitle)
    var onResult: (Data, UIImage, String?) -> Void

    @Environment(\.bgPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var controller = CoverCaptureController()
    @State private var authDenied = false
    @State private var noCamera = false

    private var cameraUsable: Bool { !authDenied && !noCamera }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !cameraUsable {
                CameraUnavailableView(message: authDenied
                    ? String(localized: "Allow the camera to photograph a cover, or go back and type the title.")
                    : String(localized: "This device has no camera. Go back and type the title instead."),
                    showSettingsLink: authDenied)
                    .ignoresSafeArea()
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
                if cameraUsable {
                    Text(controller.isCapturing
                         ? String(localized: "Hold still\u{2026}")
                         : String(localized: "Fill the frame with the cover"))
                        .font(BGFont.ui(14, .medium)).foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.opacity)
                        .padding(.bottom, 16)
                    Button { controller.capture() } label: {
                        ZStack {
                            Circle().fill(.white).frame(width: 72, height: 72)
                                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 4).padding(-6))
                                .opacity(controller.isCapturing ? 0.45 : 1)
                            if controller.isCapturing {
                                ProgressView().tint(.black)
                            }
                        }
                    }
                    .disabled(controller.isCapturing)
                    .accessibilityLabel("Take the photo")
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
        }
        .animation(.easeOut(duration: 0.18), value: controller.isCapturing)
        .task {
            let status = await CameraAccess.request()
            authDenied = (status == .denied || status == .restricted)
            noCamera = !CameraAccess.hasCamera(position: .back)
            controller.onResult = { jpeg, img, ocr in
                onResult(jpeg, img, ocr)
                dismiss()
            }
            if cameraUsable { controller.start() }
        }
        .onDisappear { controller.stop() }
        .keepAwake()
    }
}

@MainActor @Observable
final class CoverCaptureController {
    let camera = CameraSession(position: .back, photoCapture: true)
    var onResult: ((Data, UIImage, String?) -> Void)?

    /// From the tap until the cover is handed back — the shutter is disabled and says so.
    private(set) var isCapturing = false

    private var done = false

    func start() { camera.start() }
    func stop() { camera.stop(); camera.onFrame = nil }

    func capture() {
        guard !isCapturing, !done else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        camera.capturePhoto { [weak self] data in
            Task { @MainActor [weak self] in self?.finish(data) }
        }
    }

    private func finish(_ data: Data?) {
        guard !done else { return }
        guard let data, let photo = UIImage(data: data) else {
            // Nothing captured — give the button back rather than leaving a dead shutter.
            isCapturing = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        done = true

        // Down to a cover-sized JPEG: a full-resolution still is several megabytes, and this is
        // stored per book and only ever drawn a few hundred points wide.
        let jpeg = ImageStorage.jpeg(from: photo, maxDimension: 1600, quality: 0.9) ?? data
        let image = UIImage(data: jpeg) ?? photo

        // OCR runs after the picture is in hand, off the capture path. Folding it into the same
        // step meant its second or two of work was charged to "taking the photo".
        Task { [weak self] in
            let title = await Self.ocrTitle(from: image)
            await MainActor.run { self?.onResult?(jpeg, image, title) }
        }
    }

    /// Best-effort: the largest recognised text line, which is usually the title.
    private static func ocrTitle(from image: UIImage) async -> String? {
        guard let cg = image.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])
            guard let results = request.results, !results.isEmpty else { return nil }
            // The observation with the tallest bounding box (largest type = likely the title).
            let best = results.max { $0.boundingBox.height < $1.boundingBox.height }
            return best?.topCandidates(1).first?.string
        }.value
    }
}
