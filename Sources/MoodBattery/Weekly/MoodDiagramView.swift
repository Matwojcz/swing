import SwiftUI

enum DiagramScale: String, CaseIterable {
    case week, month, year

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    var label: String { rawValue.capitalized }
}

struct MoodDiagramView: View {
    let entries: [MoodEntry]

    @State private var scale: DiagramScale = .week
    @State private var pageOffset: Int = 0
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var magnifyAnchor: CGFloat = 1.0

    private let height: CGFloat = 150
    private let verticalPadding: CGFloat = 14
    private let dotRadius: CGFloat = 4

    private var calendar: Calendar { Calendar.current }

    private var pageEndDate: Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: pageOffset * scale.dayCount, to: today)!
    }

    private var days: [Date] {
        let end = pageEndDate
        return (0..<scale.dayCount).map {
            calendar.date(byAdding: .day, value: $0 - (scale.dayCount - 1), to: end)!
        }
    }

    private struct DataPoint {
        var dayIndex: Int
        var energy: Double
        var flavour: Double
    }

    private var dataPoints: [DataPoint] {
        switch scale {
        case .week:
            return dailyAverages
        case .month:
            return dailyAverages
        case .year:
            return weeklyAveragesForYear
        }
    }

    private var dailyAverages: [DataPoint] {
        days.enumerated().compactMap { index, day in
            let dayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { return nil }
            let count = Double(dayEntries.count)
            let avgEnergy = dayEntries.reduce(0) { $0 + $1.energy } / count
            let avgFlavour = dayEntries.reduce(0) { $0 + $1.flavour } / count
            return DataPoint(dayIndex: index, energy: avgEnergy, flavour: avgFlavour)
        }
    }

    private var weeklyAveragesForYear: [DataPoint] {
        let daysList = days
        var points: [DataPoint] = []
        let chunkSize = 7
        let chunkCount = daysList.count / chunkSize

        for chunk in 0..<chunkCount {
            let startIdx = chunk * chunkSize
            let midIdx = startIdx + chunkSize / 2
            var energySum = 0.0
            var flavourSum = 0.0
            var count = 0.0

            for i in startIdx..<(startIdx + chunkSize) {
                let day = daysList[i]
                let dayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
                for e in dayEntries {
                    energySum += e.energy
                    flavourSum += e.flavour
                    count += 1
                }
            }

            if count > 0 {
                points.append(DataPoint(
                    dayIndex: midIdx,
                    energy: energySum / count,
                    flavour: flavourSum / count
                ))
            }
        }
        return points
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthHeader

            ZStack {
                if dataPoints.isEmpty {
                    Text("No entries for this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Canvas { context, size in
                        drawBaseline(in: context, size: size)
                        drawSeries(in: context, size: size)
                    }
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .gesture(pinchGesture)

            dayLabels

            scaleIndicator
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Text(monthLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if pageOffset != 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pageOffset = 0 }
                } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthLabel: String {
        let daysList = days
        guard let first = daysList.first, let last = daysList.last else { return "" }

        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)
        let firstYear = calendar.component(.year, from: first)
        let lastYear = calendar.component(.year, from: last)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        if scale == .year {
            if firstYear == lastYear {
                return "\(firstYear)"
            }
            return "\(firstYear) – \(lastYear)"
        }

        let firstMonthName = monthFormatter.string(from: first)
        let lastMonthName = monthFormatter.string(from: last)

        if firstMonth == lastMonth && firstYear == lastYear {
            return "\(firstMonthName) \(firstYear)"
        }
        if firstYear == lastYear {
            return "\(firstMonthName) – \(lastMonthName) \(lastYear)"
        }
        return "\(firstMonthName) \(firstYear) – \(lastMonthName) \(lastYear)"
    }

    // MARK: - Day labels

    private var dayLabels: some View {
        HStack(spacing: 0) {
            switch scale {
            case .week:
                ForEach(days, id: \.self) { day in
                    Text(Self.shortDayFormatter.string(from: day))
                        .font(.caption2)
                        .foregroundStyle(calendar.isDateInToday(day) ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
            case .month:
                ForEach([0, 7, 14, 21, 29], id: \.self) { idx in
                    if idx < days.count {
                        Text(Self.dayMonthFormatter.string(from: days[idx]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .year:
                ForEach(0..<12, id: \.self) { monthIdx in
                    let dayIdx = monthIdx * 30
                    if dayIdx < days.count {
                        Text(Self.shortMonthFormatter.string(from: days[min(dayIdx, days.count - 1)]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: - Scale indicator

    private var scaleIndicator: some View {
        HStack(spacing: 0) {
            ForEach(DiagramScale.allCases, id: \.self) { s in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scale = s
                        pageOffset = 0
                    }
                } label: {
                    Text(s.label)
                        .font(.system(size: 11, weight: s == scale ? .semibold : .regular))
                        .foregroundStyle(s == scale ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            s == scale
                                ? RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.tankSurface)
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    withAnimation(.easeInOut(duration: 0.2)) { pageOffset -= 1 }
                } else if value.translation.width > threshold {
                    if pageOffset < 0 {
                        withAnimation(.easeInOut(duration: 0.2)) { pageOffset += 1 }
                    }
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                magnifyAnchor = value.magnification
            }
            .onEnded { value in
                let mag = value.magnification
                withAnimation(.easeInOut(duration: 0.25)) {
                    if mag < 0.7 {
                        zoomOut()
                    } else if mag > 1.4 {
                        zoomIn()
                    }
                }
                magnifyAnchor = 1.0
            }
    }

    private func zoomIn() {
        switch scale {
        case .year: scale = .month
        case .month: scale = .week
        case .week: break
        }
        pageOffset = 0
    }

    private func zoomOut() {
        switch scale {
        case .week: scale = .month
        case .month: scale = .year
        case .year: break
        }
        pageOffset = 0
    }

    // MARK: - Geometry

    private func x(forDayIndex index: Int, size: CGSize) -> CGFloat {
        let totalDays = scale.dayCount
        let dayWidth = size.width / CGFloat(totalDays)
        return (CGFloat(index) + 0.5) * dayWidth
    }

    private func y(for energy: Double, size: CGSize) -> CGFloat {
        let usable = size.height - verticalPadding * 2
        return verticalPadding + CGFloat(1 - energy / 100) * usable
    }

    private func point(for dp: DataPoint, size: CGSize) -> CGPoint {
        CGPoint(x: x(forDayIndex: dp.dayIndex, size: size), y: y(for: dp.energy, size: size))
    }

    // MARK: - Drawing

    private func drawBaseline(in context: GraphicsContext, size: CGSize) {
        let baselineY = y(for: 50, size: size)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baselineY))
        path.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(path, with: .color(.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private func drawSeries(in context: GraphicsContext, size: CGSize) {
        let plotted = dataPoints.map { dp in
            (pos: point(for: dp, size: size),
             color: MoodColor.color(energy: dp.energy, flavour: dp.flavour))
        }
        guard !plotted.isEmpty else { return }

        if plotted.count > 1 {
            for i in 1..<plotted.count {
                let a = plotted[i - 1]
                let b = plotted[i]
                var path = Path()
                path.move(to: a.pos)
                path.addLine(to: b.pos)
                context.stroke(
                    path,
                    with: .linearGradient(Gradient(colors: [a.color, b.color]),
                                          startPoint: a.pos, endPoint: b.pos),
                    lineWidth: 2
                )
            }
        }

        let radius = scale == .year ? 3.0 : dotRadius
        for p in plotted {
            let rect = CGRect(x: p.pos.x - radius, y: p.pos.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(p.color))
            context.stroke(Path(ellipseIn: rect), with: .color(.tankBorder), lineWidth: 1)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let sample: [MoodEntry] = (0..<60).map { i in
        MoodEntry(
            id: Int64(i),
            energy: Double.random(in: 10...95),
            flavour: Double.random(in: 0...1),
            title: nil,
            note: nil,
            timestamp: calendar.date(byAdding: .day, value: -i, to: now) ?? now
        )
    }
    MoodDiagramView(entries: sample)
        .padding(24)
        .frame(width: 560)
}
