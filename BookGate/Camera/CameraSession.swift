import AVFoundation

/// A thin front-camera capture pump. Owns an `AVCaptureSession`, streams frames
/// as `CVPixelBuffer`s via `onFrame` (on a background queue), and vends the
/// preview layer. Deliberately hardware-only and logic-free so the pushup rep
/// logic (`PushupRepCounter`) stays pure and testable.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "app.bookgate.camera.frames")
    private let position: AVCaptureDevice.Position
    private var configured = false

    /// Delivered on the capture queue for every frame.
    var onFrame: ((CVPixelBuffer) -> Void)?

    init(position: AVCaptureDevice.Position = .front) {
        self.position = position
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }

        // Deliver frames upright in portrait so Vision's `.up` orientation is
        // correct (a pushup's up/down motion maps cleanly to the Y axis), and
        // mirror the front camera to match the on-screen preview so the pose
        // keypoint overlay lines up.
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if position == .front, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
