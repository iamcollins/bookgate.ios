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
struct CameraUnavailableView: View {
    var message: String = String(localized: "Enable camera access in Settings to finish this challenge.", comment: "Camera-denied fallback message")

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0d0a1e), Color(hex: 0x241a3e)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 26, weight: .semibold))
                Text("Camera unavailable")
                    .font(.system(size: 15, weight: .semibold))
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 40)
            }
            .foregroundStyle(.white)
        }
    }
}
