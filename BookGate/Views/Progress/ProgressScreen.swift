import SwiftUI

/// Progress (month 10a / year 10b). **Three facts only** — streak, current month, total time. No
/// averages, no projections, no percentages, no goal ring. Fill weight = session length (four
/// steps), miss = hairline outline, today = brass tint + border + dot, future = numeral only.
struct ProgressScreen: View {
    @Environment(AppServices.self) private var services
    @Environment(\.bgPalette) private var palette
    @State private var monthOffset = 0          // 0 = current month; steppers move it
    @State private var showYear = false

    private var progress: ProgressStore { services.progress }
    private let cal = Calendar.current

    var body: some View {
        ZStack {
            BGAmbientBackground()
            ScrollView {
                if showYear {
                    YearGrid(showYear: $showYear).environment(services)
                } else {
                    monthContent
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var monthContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Progress").font(BGFont.screenTitle).foregroundStyle(palette.ink(.hero))
            streakRow
            monthGrid
            totalsRow
            legend
            sinceRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 64)
        .padding(.bottom, 120)
    }

    // MARK: Fact 1 — streak

    private var streakRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Bookmark(width: 26, height: 36)
            Text("\(progress.liveStreak)").font(BGFont.numeralXL).foregroundStyle(palette.ink(.hero))
            Text("Nights\nin a row").sectionLabel().fixedSize()
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(progress.bestStreak)").font(BGFont.serif(22, .medium)).foregroundStyle(palette.ink(.strong))
                Text("Longest").sectionLabel(color: palette.ink(.secondary))
            }
        }
    }

    // MARK: Fact 2 — current month heatmap

    private var displayedMonth: Date {
        cal.date(byAdding: .month, value: monthOffset, to: cal.startOfDay(for: .now)) ?? .now
    }

    private var monthGrid: some View {
        VStack(spacing: 14) {
            HStack {
                stepper("chevron.left") { monthOffset -= 1 }
                Spacer()
                Text(monthTitle(displayedMonth)).font(BGFont.serif(18, .medium)).foregroundStyle(palette.ink(.strong))
                Spacer()
                stepper("chevron.right") { if monthOffset < 0 { monthOffset += 1 } }
                    .opacity(monthOffset < 0 ? 1 : 0.3)
                    .disabled(monthOffset >= 0)
            }
            HStack(spacing: 6) {
                ForEach(Schedule.dayLetters, id: \.self) { d in
                    Text(d).font(BGFont.ui(10, .semibold)).foregroundStyle(palette.ink(.caption))
                        .frame(maxWidth: .infinity)
                }
            }
            let cells = monthCells(displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(cells.indices, id: \.self) { i in cell(cells[i]) }
            }
        }
    }

    private func stepper(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.brassValue).frame(width: 36, height: 36)
        }.buttonStyle(.plain)
    }

    private enum Cell: Equatable { case blank; case day(Date, minutes: Int?, isToday: Bool, isFuture: Bool) }

    @ViewBuilder private func cell(_ c: Cell) -> some View {
        switch c {
        case .blank:
            Color.clear.frame(height: 36)
        case let .day(date, minutes, isToday, isFuture):
            HeatCell(day: cal.component(.day, from: date), minutes: minutes,
                     isToday: isToday, isFuture: isFuture)
        }
    }

    private func monthCells(_ month: Date) -> [Cell] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        // Leading blanks: Monday-first offset.
        let weekday = cal.component(.weekday, from: first)        // 1=Sun…7=Sat
        let mondayIndex = (weekday + 5) % 7                       // 0=Mon…6=Sun
        var cells: [Cell] = Array(repeating: .blank, count: mondayIndex)
        let today = cal.startOfDay(for: .now)
        for day in range {
            guard let date = cal.date(bySetting: .day, value: day, of: first),
                  let d = cal.date(from: cal.dateComponents([.year, .month, .day], from: date)) else { continue }
            let start = cal.startOfDay(for: d)
            let isFuture = start > today
            let isToday = cal.isDateInToday(start)
            cells.append(.day(start, minutes: progress.minutes(on: start), isToday: isToday, isFuture: isFuture))
        }
        return cells
    }

    private var totalsRow: some View {
        let (read, active, minutes) = monthTotals(displayedMonth)
        return Text("\(read) of \(active) nights · \(hoursMinutes(minutes))")
            .font(BGFont.body).foregroundStyle(palette.ink(.body))
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

    // MARK: Fact 3 — totals since start + Year chip

    private var sinceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sinceLabel).sectionLabel(color: palette.ink(.secondary))
                Text("\(progress.totalNights) nights · \(hoursMinutes(progress.totalMinutes))")
                    .font(BGFont.serif(22, .medium)).foregroundStyle(palette.ink(.hero))
            }
            Spacer()
            Button { showYear = true } label: {
                Text("Year").font(BGFont.ui(13, .semibold)).foregroundStyle(palette.brassValue)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .glass(.card, cornerRadius: 15)
            }.buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private func monthTitle(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"; return df.string(from: d)
    }
    private func monthTotals(_ month: Date) -> (read: Int, active: Int, minutes: Int) {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return (0,0,0) }
        let today = cal.startOfDay(for: .now)
        var read = 0, active = 0, minutes = 0
        for day in range {
            guard let d = cal.date(bySetting: .day, value: day, of: first) else { continue }
            let start = cal.startOfDay(for: d)
            if start > today { continue }
            active += 1
            if let m = progress.minutes(on: start) { read += 1; minutes += m }
        }
        return (read, active, minutes)
    }
    private func hoursMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    private var sinceLabel: String {
        guard let earliest = progress.nights.keys.min() else { return String(localized: "All time") }
        let df = DateFormatter(); df.dateFormat = "MMMM"
        return String(localized: "Since \(df.string(from: earliest))")
    }
}

/// A single heatmap day cell.
private struct HeatCell: View {
    let day: Int
    let minutes: Int?
    let isToday: Bool
    let isFuture: Bool
    @Environment(\.bgPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isFuture {
                // numeral only, no cell
                Text("\(day)").font(BGFont.ui(11, .regular)).foregroundStyle(palette.ink(.disabled))
            } else if let minutes {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.heatmapFills[weightIndex(minutes)])
                Text("\(day)").font(BGFont.ui(11, .semibold))
                    .foregroundStyle(weightIndex(minutes) >= 2 ? palette.actionText : palette.ink(.strong))
            } else if isToday {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.brassLabel.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(palette.brassLabel, lineWidth: 1.3))
                Text("\(day)").font(BGFont.ui(11, .semibold)).foregroundStyle(palette.brassValue)
                Circle().fill(palette.brassLabel).frame(width: 4, height: 4)
                    .offset(y: 11)
                    .opacity(reduceMotion ? 1 : (pulse ? 0.95 : 0.4))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
            } else {
                // miss — hairline outline, no fill, no red
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(palette.hairline, lineWidth: 1.3)
                Text("\(day)").font(BGFont.ui(11, .regular)).foregroundStyle(palette.ink(.caption))
            }
            if isToday { Color.clear }
        }
        .frame(height: 36)
        .onAppear { pulse = true }
    }

    private func weightIndex(_ minutes: Int) -> Int {
        switch minutes {
        case ..<10: return 0
        case ..<20: return 1
        case ..<45: return 2
        default: return 3
        }
    }
}
