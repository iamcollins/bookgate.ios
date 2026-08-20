#if DEBUG
import SwiftUI
import ShotKit

/// BookGate's App Store frames: espresso night, brass accent, Newsreader captions — the app's own
/// identity rather than ShotKit's neutral default, so the store listing and the app read as one
/// thing. ShotKit owns the layout, the device and the light/dark separation logic.
extension StoreFrameStyle {
    static var bookGate: StoreFrameStyle {
        StoreFrameStyle(
            background: AnyView(
                LinearGradient(colors: [Color(hex: 0x241A12), Color(hex: 0x100C09)],
                               startPoint: .top, endPoint: .bottom)
            ),
            // The dominant colour of that gradient — what the finish choice and the contrast
            // guard are measured against.
            backgroundReference: Color(hex: 0x1A1310),
            ink: Color(hex: 0xF7EFE4),
            accent: Color(hex: 0xE9B872),
            captionFont: { size, weight in
                ShotMode.captionFontName.map { Font.custom($0, fixedSize: size).weight(weight) }
                    ?? BGFont.serif(size, weight)
            },
            captionUIFont: { size, weight in newsreader(size, weight) }
        )
    }

    /// UIKit twin of `BGFont.serif`, used to measure a caption before it is drawn. `UIFont(name:)`
    /// wants a PostScript name and Newsreader is registered by family, so go through a descriptor
    /// and fall back to the system serif rather than silently measuring the wrong face.
    private static func newsreader(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: BGFont.serifFamily,
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        guard font.familyName == BGFont.serifFamily else {
            return .systemFont(ofSize: size, weight: weight)
        }
        return font
    }
}

/// What the driver script stages in the app container for the store-frame pass: the caption copy
/// and the previous pass's PNGs. Both live in the container rather than the app bundle — App Store
/// marketing copy has no business shipping inside the app.
enum ShotSource {
    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// `Scripts/store_captions.json`, copied in by the driver (`CONTAINER_ASSETS`).
    static var captionsURL: URL { documents.appendingPathComponent("store_captions.json") }

    static func image(named source: String) -> UIImage? {
        UIImage(contentsOfFile: documents.appendingPathComponent("source/\(source).png").path)
    }
}
#endif
