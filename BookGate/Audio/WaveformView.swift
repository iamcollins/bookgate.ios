import SwiftUI

/// A takeaway waveform: 3px bars, 2.5px gaps. Bars up to `progress` are brass (played); the rest are
/// dim ink. Used live while recording (progress = 1) and during playback (progress = play head).
struct WaveformView: View {
    var levels: [Float]
    var progress: Double = 1
    var height: CGFloat = 24
    var barWidth: CGFloat = 3
    var gap: CGFloat = 2.5

    @Environment(\.bgPalette) private var palette

    var body: some View {
        GeometryReader { geo in
            let count = max(1, Int((geo.size.width + gap) / (barWidth + gap)))
            let bars = resampled(to: count)
            let playedCount = Int(Double(count) * progress)
            HStack(alignment: .center, spacing: gap) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < playedCount ? AnyShapeStyle(palette.brassObject)
                                              : AnyShapeStyle(palette.ink(.disabled).opacity(palette.isDark ? 0.66 : 0.85)))
                        .frame(width: barWidth, height: max(2, CGFloat(bars[i]) * height))
                }
            }
            .frame(width: geo.size.width, height: height, alignment: .leading)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    /// Fit the stored levels to the number of visible bars; if empty, a gentle flat line.
    private func resampled(to count: Int) -> [Float] {
        guard !levels.isEmpty else { return Array(repeating: 0.15, count: count) }
        if levels.count == count { return normalized(levels) }
        let step = Double(levels.count) / Double(count)
        return normalized((0..<count).map { levels[min(levels.count - 1, Int(Double($0) * step))] })
    }

    private func normalized(_ v: [Float]) -> [Float] {
        let maxV = max(0.2, v.max() ?? 1)
        return v.map { 0.12 + 0.88 * ($0 / maxV) }   // floor so quiet bars still show
    }
}
