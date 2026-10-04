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
    var scrollToDate: Date?
    /// The entry currently selected elsewhere in the app; its dot (or, on the year scale, its week's dot) gets a mood-coloured ring that fades in and out as the selection changes.
    var highlightedEntry: MoodEntry?

    @State private var scale: DiagramScale = .week
    @State private var currentPage: Int?
    @State private var magnifyAnchor: CGFloat = 1.0

    private let height: CGFloat = 150
    private let verticalPadding: CGFloat = 14
    private let dotRadius: CGFloat = 4

    private var calendar: Calendar { Calendar.current }

    private var pageCount: Int { scale.pageCount }

    /// Returns the array of calendar dates visible on the given page, working backwards from today.
    private func daysForPage(_ page: Int) -> [Date] {
        let offset = page - (pageCount - 1)
        let today = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: offset * scale.dayCount, to: today)!
        return (0..<scale.dayCount).map {
            calendar.date(byAdding: .day, value: $0 - (scale.dayCount - 1), to: end)!
        }
    }

    /// Extends a page's date range by borrowing days from adjacent pages so mood lines connect across boundaries.
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
        .onChange(of: scrollToDate) { _, date in
            guard let date else { return }
            let today = calendar.startOfDay(for: Date())
            let target = calendar.startOfDay(for: date)
            let daysBetween = calendar.dateComponents([.day], from: target, to: today).day ?? 0
            let weekPage = (pageCount - 1) - (daysBetween / 7)
            withAnimation(.easeInOut(duration: 0.25)) {
                scale = .week
                currentPage = max(0, min(pageCount - 1, weekPage))
            }
        }
    }

    // MARK: - Page content

    /// Builds the full content for one diagram page: Canvas with episodes, baseline, mood line, a highlight ring for the selected entry (drawn as an overlay so it can fade), plus tap targets and day labels.
    private func diagramPage(page: Int) -> some View {
        let days = daysForPage(page)

        let drawingPoints: [MoodDataAggregator.DataPoint]
        let tappablePoints: [MoodDataAggregator.DataPoint]

        if scale == .year {
            let pts = dataPoints(for: days)
            drawingPoints = pts
            tappablePoints = pts
        } else {
            let boundary = boundaryDataPoints(for: page)
            drawingPoints = boundary.drawing
            tappablePoints = boundary.tappable
        }

        let pageEpisodes = episodesForPage(days)

        return VStack(spacing: 4) {
            ZStack {
                if drawingPoints.isEmpty {
                    Text("No entries for this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Canvas { context, size in
                        drawEpisodes(pageEpisodes, in: context, size: size)
                        drawBaseline(in: context, size: size)
                        drawSeries(drawingPoints, in: context, size: size,
                                   dotRange: 0..<scale.dayCount)
                    }

                    GeometryReader { geo in
                        if let point = highlightedPoint(in: tappablePoints, days: days) {
                            highlightRing(for: point, in: geo.size)
                                .id(point.dayIndex)
                                .transition(.opacity)
                        }
                    }
                    .allowsHitTesting(false)
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
                                let baselineY = y(for: MoodScale.baseline, height: geo.size.height)
                                Color.clear
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                                    .position(x: px, y: baselineY)
                                    .onTapGesture { onSelectDate?(days[dayIdx]) }
                            }
                        }
                    }
                } else if scale == .month {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let dayIdx = Int(location.x / geo.size.width * CGFloat(scale.dayCount))
                                let clampedIdx = max(0, min(scale.dayCount - 1, dayIdx))
                                let tappedDate = days[clampedIdx]
                                zoomToDate(tappedDate, from: .month)
                            }
                    }
                } else {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let dayIdx = Int(location.x / geo.size.width * CGFloat(scale.dayCount))
                                let clampedIdx = max(0, min(scale.dayCount - 1, dayIdx))
                                let tappedDate = days[clampedIdx]
                                zoomToDate(tappedDate, from: .year)
                            }
                    }
                }
            }
            .frame(height: height)

            dayLabels(for: days)
        }
    }

    /// Finds the plotted point on this page that stands for `highlightedEntry`: the same day on week/month scales, or the 7-day chunk containing that day on the year scale.
    private func highlightedPoint(in points: [MoodDataAggregator.DataPoint], days: [Date]) -> MoodDataAggregator.DataPoint? {
        guard let entry = highlightedEntry else { return nil }
        let day = entry.day(in: calendar)
        if scale == .year {
            guard let idx = days.firstIndex(of: day) else { return nil }
            let midIdx = (idx / 7) * 7 + 3
            return points.first { $0.dayIndex == midIdx }
        }
        return points.first { calendar.startOfDay(for: $0.date) == day }
    }

    /// Draws a soft halo and ring around a point, coloured like the point itself. Inserted/removed with an opacity transition so it crossfades between dots when the selection moves.
    private func highlightRing(for point: MoodDataAggregator.DataPoint, in size: CGSize) -> some View {
        let color = MoodColor.color(mood: point.mood, flavour: point.flavour)
        let ringRadius = (scale == .year ? 3.0 : dotRadius) + 5
        return ZStack {
            Circle().fill(color.opacity(0.25))
            Circle().stroke(color, lineWidth: 2)
        }
        .frame(width: ringRadius * 2, height: ringRadius * 2)
        .position(x: x(forDayIndex: point.dayIndex, totalDays: scale.dayCount, width: size.width),
                  y: y(for: point.mood, height: size.height))
    }

    /// Zooms in one level (year→month, month→week) and navigates to the page containing the tapped date.
    private func zoomToDate(_ date: Date, from currentScale: DiagramScale) {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let daysBetween = calendar.dateComponents([.day], from: target, to: today).day ?? 0

        withAnimation(.easeInOut(duration: 0.25)) {
            switch currentScale {
            case .year:
                scale = .month
                let monthPage = (pageCount - 1) - (daysBetween / 30)
                currentPage = max(0, min(pageCount - 1, monthPage))
            case .month:
                scale = .week
                let weekPage = (pageCount - 1) - (daysBetween / 7)
                currentPage = max(0, min(pageCount - 1, weekPage))
            case .week:
                break
            }
        }
    }

    // MARK: - Data

    /// Selects the aggregation strategy (daily or weekly averages) based on the current diagram scale.
    private func dataPoints(for days: [Date]) -> [MoodDataAggregator.DataPoint] {
        switch scale {
        case .week, .month:
            return MoodDataAggregator.dailyAverages(entries: entries, days: days, calendar: calendar)
        case .year:
            return MoodDataAggregator.weeklyAverages(entries: entries, days: days, calendar: calendar)
        }
    }

    /// Computes data points including boundary days from adjacent pages, returning both the full drawing set and the tappable subset.
    /// The dayIndex is remapped so this page's own days occupy 0..<dayCount and boundary days sit at negative indices or beyond, off-canvas.
    private func boundaryDataPoints(for page: Int) -> (drawing: [MoodDataAggregator.DataPoint], tappable: [MoodDataAggregator.DataPoint]) {
        let (extDays, ownStart) = extendedDaysForPage(page)
        let raw = MoodDataAggregator.dailyAverages(entries: entries, days: extDays, calendar: calendar)
        let remapped = raw.map { dp in
            MoodDataAggregator.DataPoint(
                dayIndex: dp.dayIndex - ownStart,
                mood: dp.mood,
                flavour: dp.flavour,
                date: dp.date
            )
        }
        let tappable = remapped.filter { $0.dayIndex >= 0 && $0.dayIndex < scale.dayCount }
        return (remapped, tappable)
    }

    // MARK: - Month header

    /// Builds the header showing the month/year label and an optional "Today" button to jump to the latest page.
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

    /// Formats the page's date range into a human-readable label (e.g. "March 2025" or "March – April 2025").
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

    /// Renders the date labels beneath the diagram, adapted to the current scale (daily, weekly samples, or monthly).
    /// Builds the row of x-axis labels: one per day (week), five spaced dates (month), or one per calendar month in the span (year, found by scanning `days` for each month's first appearance).
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
                ForEach(monthStartDays(in: days), id: \.self) { day in
                    Text(Self.shortMonthFormatter.string(from: day))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Scans `days` once and returns the first day of each (year, month) pair that appears, so the year scale labels every calendar month exactly once (up to 13 for a 365-day span).
    private func monthStartDays(in days: [Date]) -> [Date] {
        var seen = Set<Int>()
        return days.filter { day in
            let c = calendar.dateComponents([.year, .month], from: day)
            return seen.insert((c.year ?? 0) * 12 + (c.month ?? 0)).inserted
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
                        currentPage = pageCount - 1
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

    /// Steps the diagram scale one level closer (year→month→week) and resets to the latest page.
    private func zoomIn() {
        switch scale {
        case .year: scale = .month
        case .month: scale = .week
        case .week: break
        }
        currentPage = pageCount - 1
    }

    /// Steps the diagram scale one level wider (week→month→year) and resets to the latest page.
    private func zoomOut() {
        switch scale {
        case .week: scale = .month
        case .month: scale = .year
        case .year: break
        }
        currentPage = pageCount - 1
    }

    // MARK: - Geometry

    /// Maps a day index to its horizontal centre position within the canvas width.
    private func x(forDayIndex index: Int, totalDays: Int, width: CGFloat) -> CGFloat {
        let dayWidth = width / CGFloat(totalDays)
        return (CGFloat(index) + 0.5) * dayWidth
    }

    /// Maps a mood value to its vertical position (0=top/hype, max=bottom/depressive) within the canvas height.
    private func y(for mood: Double, height: CGFloat) -> CGFloat {
        let usable = height - verticalPadding * 2
        return verticalPadding + CGFloat(1 - MoodScale.normalized(mood)) * usable
    }

    // MARK: - Drawing

    /// Draws a dashed horizontal line at the baseline mood level across the full canvas width.
    private func drawBaseline(in context: GraphicsContext, size: CGSize) {
        let baselineY = y(for: MoodScale.baseline, height: size.height)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baselineY))
        path.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(path, with: .color(.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    // MARK: - Episode clipping

    /// A single episode positioned within a specific diagram page, with flags for whether it extends past this page's edges.
    private struct PageEpisode {
        var startIndex: Int
        var endIndex: Int
        var extendsLeft: Bool
        var extendsRight: Bool
        var episode: EpisodeDetector.Episode
    }

    /// Runs global episode detection once for the current entries; the diagram then clips these per page.
    private var globalEpisodes: [EpisodeDetector.Episode] {
        EpisodeDetector.detect(entries: entries, calendar: calendar)
    }

    /// Clips global episodes to a page's date range, tracking whether each band extends beyond the page edges.
    private func episodesForPage(_ days: [Date]) -> [PageEpisode] {
        guard let pageStart = days.first, let pageEnd = days.last else { return [] }
        var result: [PageEpisode] = []

        for ep in globalEpisodes {
            if ep.endDate < pageStart || ep.startDate > pageEnd { continue }

            let extendsLeft = ep.startDate < pageStart
            let extendsRight = ep.endDate > pageEnd

            let clippedStart = max(ep.startDate, pageStart)
            let clippedEnd = min(ep.endDate, pageEnd)

            let startIdx = max(0, calendar.dateComponents([.day], from: pageStart, to: clippedStart).day ?? 0)
            let endIdx = min(days.count - 1, calendar.dateComponents([.day], from: pageStart, to: clippedEnd).day ?? 0)

            result.append(PageEpisode(startIndex: startIdx, endIndex: endIdx, extendsLeft: extendsLeft, extendsRight: extendsRight, episode: ep))
        }
        return result
    }

    /// Draws translucent colour bands for detected mood episodes, extending to page edges where they cross boundaries.
    private func drawEpisodes(_ pageEpisodes: [PageEpisode], in context: GraphicsContext, size: CGSize) {
        let totalDays = scale.dayCount
        let fadeWidth: CGFloat = 12

        for item in pageEpisodes {
            let left = item.extendsLeft ? 0 : x(forDayIndex: item.startIndex, totalDays: totalDays, width: size.width) - 4
            let right = item.extendsRight ? size.width : x(forDayIndex: item.endIndex, totalDays: totalDays, width: size.width) + 4
            let rect = CGRect(x: left, y: 0, width: right - left, height: size.height)

            let baseColor = MoodColor.color(mood: item.episode.averageMood, flavour: item.episode.averageFlavour)
            let bandColor = baseColor.opacity(0.12)

            let cornerRadius: CGFloat = (item.extendsLeft || item.extendsRight) ? 0 : 4
            context.fill(Path(roundedRect: rect, cornerRadius: cornerRadius), with: .color(bandColor))

            if rect.width > fadeWidth * 2 {
                if !item.extendsLeft {
                    let fadeLeft = CGRect(x: left, y: 0, width: fadeWidth, height: size.height)
                    context.fill(
                        Path(fadeLeft),
                        with: .linearGradient(
                            Gradient(colors: [.clear, bandColor]),
                            startPoint: CGPoint(x: left, y: 0),
                            endPoint: CGPoint(x: left + fadeWidth, y: 0)
                        )
                    )
                }
                if !item.extendsRight {
                    let fadeRight = CGRect(x: right - fadeWidth, y: 0, width: fadeWidth, height: size.height)
                    context.fill(
                        Path(fadeRight),
                        with: .linearGradient(
                            Gradient(colors: [bandColor, .clear]),
                            startPoint: CGPoint(x: right - fadeWidth, y: 0),
                            endPoint: CGPoint(x: right, y: 0)
                        )
                    )
                }
            }
        }
    }

    /// Draws the mood line (gradient segments between points) and dots, optionally restricting dots to a day index range to hide boundary points.
    private func drawSeries(_ points: [MoodDataAggregator.DataPoint], in context: GraphicsContext, size: CGSize, dotRange: Range<Int>? = nil) {
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
            mood: Double.random(in: 1...9.5),
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
