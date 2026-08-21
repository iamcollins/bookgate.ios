import SwiftUI
import AVFoundation
import UIKit

/// Hosts an `AVCaptureVideoPreviewLayer` sized to fill — the shared live-feed
/// background used by every camera-backed challenge (pushups, make-my-bed,
/// take-a-pic, move-around). Logic-free: it only mirrors a `CameraSession`'s
/// running `AVCaptureSession` onto the screen.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        #if DEBUG
        // Screenshot driver: the Simulator has no camera, so swap the live feed
        // for a supplied still (BOOKGATE_CAMERA_IMAGE, loaded from Documents). The
        // real challenge UI then renders over a real photo — see ScreenshotCamera.
        if let img = ScreenshotCamera.image {
            view.setInjected(img)
            return view
        }
        #endif
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        #if DEBUG
        private var injected: UIImageView?
        func setInjected(_ image: UIImage) {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            addSubview(iv); injected = iv; setNeedsLayout()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            injected?.frame = bounds
        }
        #endif
    }
}

#if DEBUG
/// Loads the screenshot stand-in photo named by `BOOKGATE_CAMERA_IMAGE` from the
/// app's Documents directory (the capture script copies it in before launch).
enum ScreenshotCamera {
    static let image: UIImage? = {
        guard let name = ProcessInfo.processInfo.environment["BOOKGATE_CAMERA_IMAGE"], !name.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let img = UIImage(contentsOfFile: docs.appendingPathComponent(name).path)
        else { return nil }
        return img
    }()
}
#endif

/// The fallback shown behind the firing ring when a camera challenge can't use
/// the camera (permission denied / restricted). Mirrors the app's calm gradient
/// so the ring + copy stay legible; the `message` tailors the ask per challenge.
/// What a camera screen shows when there is no picture to show: access was refused, or the device
/// has no such camera. Always paired with a way forward — every camera moment in BookGate has a
/// manual path, so this is an explanation, never a dead end.
///
/// (It used to be drawn in a deep indigo carried over from the app this camera stack came from,
/// which was the one purple surface in an otherwise warm app.)
struct CameraUnavailableView: View {
    var message: String = String(localized: "Enable camera access in Settings to carry on.",
                                 comment: "Camera-denied fallback message")
    /// Shown only when the block is a permission the user can actually change.
    var showSettingsLink: Bool = false

    @Environment(\.bgPalette) private var palette

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A120B), Color(hex: 0x0F0A07)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color(hex: 0xE9B872, opacity: 0.8))
                Text("No picture here")
                    .font(BGFont.serif(19, .medium))
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.92))
                Text(message)
                    .font(BGFont.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0xF7EFE4, opacity: 0.62))
                    .padding(.horizontal, 26)
                if showSettingsLink, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .font(BGFont.ui(13, .semibold))
                        .foregroundStyle(Color(hex: 0xE9B872))
                        .frame(height: 44)
                }
            }
            .padding(.vertical, 24)
        }
    }
}
