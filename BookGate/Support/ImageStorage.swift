import UIKit
import CoreImage
import CoreVideo
import ImageIO

/// The app's first on-disk storage: JPEG stills captured during a wake-up live in
/// `Documents/Gallery/`, referenced by filename from `GalleryStore` (the metadata
/// index stays in UserDefaults). Everything here is **local to the device** — the
/// app never uploads these images.
struct ImageStorage {

    /// One shared context — creating a `CIContext` per frame is expensive, and it's
    /// safe to reuse across the camera queue and the main actor.
    private static let ciContext = CIContext()

    /// `Documents/Gallery`, created on first use.
    private var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Gallery", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Absolute URL for a stored file name.
    func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Write JPEG bytes under `name`. Returns false if the write fails.
    @discardableResult
    func write(_ data: Data, name: String) -> Bool {
        do { try data.write(to: url(for: name), options: .atomic); return true }
        catch { return false }
    }

    /// Load a stored still as a full-resolution `UIImage`, or nil if it's
    /// missing/unreadable. For grid tiles use `thumbnail(_:maxPixel:)` instead —
    /// decoding the full image just to show a small tile is what janked scrolling.
    func loadImage(_ name: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: name)) else { return nil }
        return UIImage(data: data)
    }

    /// A downsampled thumbnail decoded straight to `maxPixel` via ImageIO — reads
    /// only the pixels it needs, so a multi-megapixel camera still becomes a small
    /// tile cheaply. Nil if missing/unreadable.
    func thumbnail(_ name: String, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,     // honour EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Delete stored files by name (missing files are ignored).
    func delete(_ names: [String]) {
        for name in names { try? FileManager.default.removeItem(at: url(for: name)) }
    }

    /// Whether a stored file still exists on disk.
    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: name).path)
    }

    // MARK: Conversion

    /// Encode a camera `CVPixelBuffer` (BGRA) to JPEG data. Safe to call off the
    /// main actor (the camera frame queue). The Move Around front-camera feed is
    /// already delivered upright and mirrored (its `AVCaptureConnection` sets a 90°
    /// rotation + mirroring), so the buffer needs no extra orientation fix-up.
    static func jpeg(from pixelBuffer: CVPixelBuffer, quality: CGFloat = 0.8) -> Data? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: quality)
    }

    /// Re-encode a photograph down to a stored size, longest side first. A full-resolution still
    /// off `AVCapturePhotoOutput` is several megabytes; a cover is never drawn larger than a
    /// screen, and one of these is kept per book forever.
    static func jpeg(from image: UIImage, maxDimension: CGFloat, quality: CGFloat = 0.9) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image.jpegData(compressionQuality: quality) }

        let scale = maxDimension / longest
        let target = CGSize(width: (image.size.width * scale).rounded(),
                            height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
