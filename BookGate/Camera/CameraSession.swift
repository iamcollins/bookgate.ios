import AVFoundation

/// A thin front-camera capture pump. Owns an `AVCaptureSession`, streams frames
/// as `CVPixelBuffer`s via `onFrame` (on a background queue), and vends the
/// preview layer. Deliberately hardware-only and logic-free so the pushup rep
/// logic (`PushupRepCounter`) stays pure and testable.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "app.bookgate.camera.frames")
    private let position: AVCaptureDevice.Position
    private let wantsPhotoCapture: Bool
    private var configured = false

    private let photoLock = NSLock()
    private var photoCompletion: ((Data?) -> Void)?

    /// Delivered on the capture queue for every frame.
    var onFrame: ((CVPixelBuffer) -> Void)?

    /// `photoCapture` adds an `AVCapturePhotoOutput`. Detection feeds (the night gate) do not want
    /// one — they read the video stream continuously and never take a picture.
    init(position: AVCaptureDevice.Position = .front, photoCapture: Bool = false) {
        self.position = position
        self.wantsPhotoCapture = photoCapture
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

        if wantsPhotoCapture, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()
        configured = true
    }

    // MARK: Still capture

    /// Take an actual photograph, as JPEG data. `completion` runs on an arbitrary queue.
    ///
    /// This exists because reading a frame off the *video* output is not taking a picture: the
    /// system shutter sound belongs to `AVCapturePhotoOutput`, and so do the flash, the longer
    /// exposure and the multi-frame fusion that make a dim room work at all. A video frame in low
    /// light is a single short exposure — noisy, and late, because the feed itself drops to a
    /// slower frame rate to gather light.
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        queue.async { [weak self] in
            guard let self, self.wantsPhotoCapture, self.session.isRunning,
                  !self.photoOutput.connections.isEmpty else {
                completion(nil); return
            }
            self.photoLock.lock()
            let busy = self.photoCompletion != nil
            if !busy { self.photoCompletion = completion }
            self.photoLock.unlock()
            guard !busy else { completion(nil); return }

            // JPEG rather than the HEIF default: the cover is stored and passed around as JPEG
            // everywhere else in the app. Asking for a codec the output does not list raises, so
            // the request is conditional even though every iPhone offers JPEG.
            let settings = self.photoOutput.availablePhotoCodecTypes.contains(.jpeg)
                ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                : AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            // No flash, ever. A cover is usually glossy, so it comes back with a hotspot across
            // the title — the one part of it worth reading. The longer exposure and the frame
            // fusion are what a dim room actually needs, and those come regardless.
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func finishPhoto(_ data: Data?) {
        photoLock.lock()
        let completion = photoCompletion
        photoCompletion = nil
        photoLock.unlock()
        completion?(data)
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        finishPhoto(error == nil ? photo.fileDataRepresentation() : nil)
    }
}
