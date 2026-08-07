import Vision
import CoreVideo

/// Runs Apple's built-in scene/object classifier (`VNClassifyImageRequest`) on
/// camera frames and returns the labels it sees above a confidence threshold.
/// Fully on-device — nothing leaves the phone. Stateless and target-agnostic:
/// call it per frame off the main actor and let the caller decide (on the
/// main actor) whether any label is what it's looking for.
struct SceneClassifier {

    let minConfidence: Float

    /// Runs synchronously — call on the camera queue, not the main actor.
    /// Returns every classification at/above `minConfidence`, best first.
    func classify(in pixelBuffer: CVPixelBuffer) -> [(identifier: String, confidence: Float)] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNClassifyImageRequest()
        try? handler.perform([request])
        guard let results = request.results else { return [] }
        return results
            .filter { $0.confidence >= minConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(12)
            .map { (identifier: $0.identifier, confidence: $0.confidence) }
    }
}
