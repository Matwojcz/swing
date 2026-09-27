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

    var pageCount: Int { 52 }

    var label: String { rawValue.capitalized }
}

struct MoodDiagramView: View {
    let entries: [MoodEntry]
    var onSelectDate: ((Date) -> Void)?

    @State private var scale: DiagramScale = .week
    @State private var currentPage: Int?
    @State private var magnifyAnchor: CGFloat = 1.0

    private let height: CGFloat = 150
    private let verticalPadding: CGFloat = 14
    private let dotRadius: CGFloat = 4

    private var calendar: Calendar { Calendar.current }

    private var pageCount: Int { scale.pageCount }

    private func daysForPage(_ page: Int) -> [Date] {
        let offset = page - (pageCount - 1)
        let today = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: offset * scale.dayCount, to: today)!
        return (0..<scale.dayCount).map {
            calendar.date(byAdding: .day, value: $0 - (scale.dayCount - 1), to: end)!
        }
    }

    private func extendedDaysForPage(_ page: Int) -> (all: [Date], ownStartIndex: Int) {
        let own = daysForPage(page)
        var extended = own
        var ownStartIndex = 0

        if page > 0 {
            let prevDays = daysForPage(page - 1)
            let tail = prevDays.suffix(3)
            extended.insert(contentsOf: tail, at: 0)
            ownStartIndex = tail.count
        }

        if page < pageCount - 1 {
            let nextDays = daysForPage(page + 1)
            let head = nextDays.prefix(3)
            extended.append(contentsOf: head)
        }

        return (extended, ownStartIndex)
    }

    private var visiblePage: Int {
        currentPage ?? (pageCount - 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            monthHeader(for: visiblePage)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        diagramPage(page: page)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentPage, anchor: .center)
            .defaultScrollAnchor(.trailing)
            .frame(height: height + 30)

            scaleIndicator
                .padding(.top, 8)
        }
        .gesture(pinchGesture)
        .onChange(of: scale) { _, _ in
            currentPage = pageCount - 1
        }
    }

    // MARK: - Page content

    private func diagramPage(page: Int) -> some View {
        let days = daysForPage(page)

        let drawingPoints: [DataPoint]
        let tappablePoints: [DataPoint]

        if scale == .year {
            let pts = dataPoints(for: days)
            drawingPoints = pts
            tappablePoints = pts
        } else {
            let boundary = boundaryDataPoints(for: page)
            drawingPoints = boundary.drawing
            tappablePoints = boundary.tappable
        }

        return VStack(spacing: 4) {
            ZStack {
                if drawingPoints.isEmpty {
                    Text("No entries for this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Canvas { context, size in
                        drawBaseline(in: context, size: size)
                        drawSeries(drawingPoints, in: context, size: size,
                                   dotRange: 0..<scale.dayCount)
                    }
                }

                if scale == .week {
                    GeometryReader { geo in
                        let tappableSet = Set(tappablePoints.map(\.dayIndex))
                        ForEach(tappablePoints, id: \.dayIndex) { dp in
                            let px = x(forDayIndex: dp.dayIndex, totalDays: scale.dayCount, width: geo.size.width)
                            let py = y(for: dp.mood, height: geo.size.height)
                            Color.clear
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                .position(x: px, y: py)
                                .onTapGesture { onSelectDate?(dp.date) }
                        }

                        ForEach(0..<scale.dayCount, id: \.self) { dayIdx in
                            if !tappableSet.contains(dayIdx) {
                                let px = x(forDayIndex: dayIdx, totalDays: scale.dayCount, width: geo.size.width)
                                let baselineY = y(for: 50, height: geo.size.height)
                                Color.clear
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                                    .position(x: px, y: baselineY)
                                    .onTapGesture { onSelectDate?(days[dayIdx]) }
                            }
                        }
                    }
                } else {
                    GeometryReader { geo in
                        ForEach(tappablePoints, id: \.dayIndex) { dp in
                            let px = x(forDayIndex: dp.dayIndex, totalDays: scale.dayCount, width: geo.size.width)
                            let py = y(for: dp.mood, height: geo.size.height)
                            Color.clear
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                .position(x: px, y: py)
                                .onTapGesture { onSelectDate?(dp.date) }
                        }
                    }
                }
            }
            .frame(height: height)

            dayLabels(for: days)
        }
    }

    // MARK: - Data

    private struct DataPoint {
        var dayIndex: Int
        var mood: Double
        var flavour: Double
        var date: Date
    }

    private func dataPoints(for days: [Date]) -> [DataPoint] {
        switch scale {
        case .week, .month:
            return dailyAverages(for: days)
        case .year:
            return weeklyAverages(for: days)
        }
    }

    private func dailyAverages(for days: [Date]) -> [DataPoint] {
        days.enumerated().compactMap { index, day in
            let dayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { return nil }
            let count = Double(dayEntries.count)
            return DataPoint(
                dayIndex: index,
                mood: dayEntries.reduce(0) { $0 + $1.mood } / count,
                flavour: dayEntries.reduce(0) { $0 + $1.flavour } / count,
                date: day
            )
        }
    }

    private func boundaryDataPoints(for page: Int) -> (drawing: [DataPoint], tappable: [DataPoint]) {
        let (extDays, ownStart) = extendedDaysForPage(page)
        let raw = dailyAverages(for: extDays)
        let remapped = raw.map { dp in
            DataPoint(
                dayIndex: dp.dayIndex - ownStart,
                mood: dp.mood,
                flavour: dp.flavour,
                date: dp.date
            )
        }
        let tappable = remapped.filter { $0.dayIndex >= 0 && $0.dayIndex < scale.dayCount }
        return (remapped, tappable)
    }

    private func weeklyAverages(for days: [Date]) -> [DataPoint] {
        var points: [DataPoint] = []
        let chunkSize = 7
        let chunkCount = days.count / chunkSize

        for chunk in 0..<chunkCount {
            let startIdx = chunk * chunkSize
            let midIdx = startIdx + chunkSize / 2
            var moodSum = 0.0
            var flavourSum = 0.0
            var count = 0.0

            for i in startIdx..<(startIdx + chunkSize) {
                let day = days[i]
                let dayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
                for e in dayEntries {
                    moodSum += e.mood
                    flavourSum += e.flavour
                    count += 1
                }
            }

            if count > 0 {
                points.append(DataPoint(
                    dayIndex: midIdx,
                    mood: moodSum / count,
                    flavour: flavourSum / count,
                    date: days[midIdx]
                ))
            }
        }
        return points
    }

    // MARK: - Month header

    private func monthHeader(for page: Int) -> some View {
        let days = daysForPage(page)
        return HStack {
            Text(monthLabel(for: days))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if page < pageCount - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage = pageCount - 1
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func monthLabel(for days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }

        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)
        let firstYear = calendar.component(.year, from: first)
        let lastYear = calendar.component(.year, from: last)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        if scale == .year {
            return firstYear == lastYear ? "\(firstYear)" : "\(firstYear) – \(lastYear)"
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

    private func dayLabels(for days: [Date]) -> some View {
        HStack(spacing: 0) {
            switch scale {
            case .week:
                ForEach(days, id: \.self) { day in
                    Text(Self.dayMonthFormatter.string(from: day))
                        .font(.system(size: 10, weight: calendar.isDateInToday(day) ? .medium : .regular))
                        .foregroundStyle(calendar.isDateInToday(day) ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectDate?(day) }
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
                    }
                } label: {
                    Text(s.label)
                        .font(.system(size: 11, weight: s == scale ? .semibold : .regular))
                        .foregroundStyle(s == scale ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .modifier(GlassScaleTabModifier(isSelected: s == scale))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                let mag = value.magnification
                withAnimation(.easeInOut(duration: 0.25)) {
                    if mag < 0.7 {
                        zoomOut()
                    } else if mag > 1.4 {
                        zoomIn()
                    }
                }
            }
    }

    private func zoomIn() {
        switch scale {
        case .year: scale = .month
        case .month: scale = .week
        case .week: break
        }
        currentPage = pageCount - 1
    }

    private func zoomOut() {
        switch scale {
        case .week: scale = .month
        case .month: scale = .year
        case .year: break
        }
        currentPage = pageCount - 1
    }

    // MARK: - Geometry

    private func x(forDayIndex index: Int, totalDays: Int, width: CGFloat) -> CGFloat {
        let dayWidth = width / CGFloat(totalDays)
        return (CGFloat(index) + 0.5) * dayWidth
    }

    private func y(for mood: Double, height: CGFloat) -> CGFloat {
        let usable = height - verticalPadding * 2
        return verticalPadding + CGFloat(1 - mood / 100) * usable
    }

    // MARK: - Drawing

    private func drawBaseline(in context: GraphicsContext, size: CGSize) {
        let baselineY = y(for: 50, height: size.height)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baselineY))
        path.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(path, with: .color(.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private func drawSeries(_ points: [DataPoint], in context: GraphicsContext, size: CGSize, dotRange: Range<Int>? = nil) {
        let totalDays = scale.dayCount
        let plotted = points.enumerated().map { idx, dp in
            let pos = CGPoint(
                x: x(forDayIndex: dp.dayIndex, totalDays: totalDays, width: size.width),
                y: y(for: dp.mood, height: size.height)
            )
            return (pos: pos, color: MoodColor.color(mood: dp.mood, flavour: dp.flavour), dayIndex: dp.dayIndex)
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
            if let dotRange, !dotRange.contains(p.dayIndex) { continue }
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
            mood: Double.random(in: 10...95),
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
