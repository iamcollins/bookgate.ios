import Vision
import CoreVideo

/// Detects whether a real, reasonably-close face is in frame using Apple's
/// on-device `VNDetectFaceRectanglesRequest`. Used by the Move Around challenge
/// (front camera) to confirm the user is actually up and holding the phone — and
/// to make sure a saved keepsake snap is genuinely *them*, not a blurry frame of
/// the ceiling. Fully on-device; stateless — call per frame off the main actor.
///
/// Getting the orientation right matters: the front camera's buffers arrive
/// rotated/mirrored, so passing `.up` made Vision hunt for sideways faces and
/// mis-fire. `.leftMirrored` presents an upright, mirrored image — how a selfie
/// actually looks — so real faces are found and noise is rejected.
struct FaceDetector {

    /// Minimum face bounding-box height (fraction of the frame) that counts — so a
    /// small/distant face can't pass. Raised from the old 0.12 so only a face
    /// that's actually up close to the phone qualifies.
    let minHeight: CGFloat
    /// Minimum detector confidence, to drop weak/spurious detections.
    let minConfidence: Float

    init(minHeight: CGFloat = 0.20, minConfidence: Float = 0.5) {
        self.minHeight = minHeight
        self.minConfidence = minConfidence
    }

    /// The best qualifying face found, or nil. `box` is normalized (origin
    /// bottom-left) in the oriented image, so the caller can check framing.
    struct Hit { let box: CGRect; let confidence: Float }

    /// Runs synchronously — call on the camera queue, not the main actor.
    func detect(in pixelBuffer: CVPixelBuffer) -> Hit? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        try? handler.perform([request])
        guard let results = request.results else { return nil }
        let best = results
            .filter { $0.boundingBox.height >= minHeight && $0.confidence >= minConfidence }
            .max { $0.boundingBox.height < $1.boundingBox.height }
        guard let best else { return nil }
        return Hit(box: best.boundingBox, confidence: best.confidence)
    }

    /// Convenience: is a qualifying face present at all?
    func hasFace(in pixelBuffer: CVPixelBuffer) -> Bool { detect(in: pixelBuffer) != nil }
}
