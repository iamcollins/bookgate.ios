import SwiftUI

/// Progress — year (screen 10b). Twelve rows, one per month: label, a strip of one mark per night,
/// night count at right. Same fill weights. Months before the user started are blank; months ahead
/// are fainter. "Best month" + legend. Back chevron → month.
struct YearGrid: View {
    @Binding var showYear: Bool
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    private let cal = Calendar.current

    private var progress: ProgressStore { services.progress }
    private var year: Int { cal.component(.year, from: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Button { showYear = false } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.ink(.strong)).frame(width: 36, height: 36)
                }.buttonStyle(.plain)
                Text("\(String(year))").font(BGFont.screenTitle).foregroundStyle(palette.ink(.hero))
            }
            VStack(spacing: 12) {
                ForEach(1...12, id: \.self) { month in monthRow(month) }
            }
            bestMonth
            legend
        }
        .padding(.horizontal, 20)
        .padding(.top, 64)
        .padding(.bottom, 120)
    }

    private func monthRow(_ month: Int) -> some View {
        let stats = monthStats(month)
        return HStack(spacing: 12) {
            Text(monthAbbrev(month)).font(BGFont.ui(11, .medium))
                .foregroundStyle(palette.ink(.secondary)).frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                let days = stats.daysInMonth
                let gap: CGFloat = 2
                let markW = max(2, (geo.size.width - gap * CGFloat(days - 1)) / CGFloat(days))
                HStack(spacing: gap) {
                    ForEach(0..<days, id: \.self) { i in
                        mark(stats.marks[i], width: markW)
                    }
                }
            }
            .frame(height: 14)
            Text("\(stats.count)").font(BGFont.mono(11))
                .foregroundStyle(stats.count > 0 ? palette.ink(.strong) : palette.ink(.caption))
                .frame(width: 22, alignment: .trailing)
        }
    }

    private enum Mark { case read(Int), miss, future, beforeStart }

    private func mark(_ m: Mark, width: CGFloat) -> some View {
        Group {
            switch m {
            case .read(let idx): RoundedRectangle(cornerRadius: 2).fill(palette.heatmapFills[idx])
            case .miss:          RoundedRectangle(cornerRadius: 2).fill(palette.hairline)
            case .future:        RoundedRectangle(cornerRadius: 2).fill(palette.recess.opacity(0.5))
            case .beforeStart:   RoundedRectangle(cornerRadius: 2).fill(palette.recess)
            }
        }
        .frame(width: width, height: 14)
    }

    // MARK: Data

    private func monthStats(_ month: Int) -> (daysInMonth: Int, marks: [Mark], count: Int) {
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first) else { return (30, [], 0) }
        let today = cal.startOfDay(for: .now)
        let earliest = progress.nights.keys.min().map { cal.startOfDay(for: $0) }
        var marks: [Mark] = []; var count = 0
        for day in range {
            guard let d = cal.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            let start = cal.startOfDay(for: d)
            if start > today { marks.append(.future) }
            else if let earliest, start < earliest { marks.append(.beforeStart) }
            else if let m = progress.minutes(on: start) { marks.append(.read(weightIndex(m))); count += 1 }
            else { marks.append(.miss) }
        }
        return (range.count, marks, count)
    }

    private var bestMonth: some View {
        let best = (1...12).map { ($0, monthStats($0).count) }.max { $0.1 < $1.1 }
        return Group {
            if let best, best.1 > 0 {
                Text("Best month: \(monthAbbrev(best.0)), \(best.1) nights")
                    .font(BGFont.body).foregroundStyle(palette.ink(.body))
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("Short").font(BGFont.ui(10, .medium)).foregroundStyle(palette.ink(.caption))
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(palette.heatmapFills[i]).frame(width: 16, height: 10)
            }
            Text("Long").font(BGFont.ui(10, .medium)).foregroundStyle(palette.ink(.caption))
        }
    }

    private func monthAbbrev(_ m: Int) -> String {
        let df = DateFormatter(); return df.shortMonthSymbols[m - 1]
    }
    private func weightIndex(_ minutes: Int) -> Int {
        switch minutes { case ..<10: return 0; case ..<20: return 1; case ..<45: return 2; default: return 3 }
    }
}
