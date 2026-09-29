import SwiftUI

struct WeeklyDiagramView: View {
    let entries: [MoodEntry]

    private let width: CGFloat = 560
    private let height: CGFloat = 150
    private let verticalPadding: CGFloat = 14
    private let dotRadius: CGFloat = 4

    private var calendar: Calendar { Calendar.current }

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { calendar.date(byAdding: .day, value: $0 - 6, to: today)! }
    }

    private var dailyAverages: [(dayIndex: Int, mood: Double, flavour: Double)] {
        days.enumerated().compactMap { index, day in
            let dayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { return nil }
            let count = Double(dayEntries.count)
            let avgMood = dayEntries.reduce(0) { $0 + $1.mood } / count
            let avgFlavour = dayEntries.reduce(0) { $0 + $1.flavour } / count
            return (dayIndex: index, mood: avgMood, flavour: avgFlavour)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if dailyAverages.isEmpty {
                    Text("No entries this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Canvas { context, size in
                        drawBaseline(in: context, size: size)
                        drawSeries(in: context, size: size)
                    }
                }
            }
            .frame(width: width, height: height)

            dayLabels
        }
    }

    private var dayLabels: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                Text(Self.dayFormatter.string(from: day))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    // MARK: - Geometry

    private func x(forDayIndex index: Int, size: CGSize) -> CGFloat {
        let dayWidth = size.width / 7
        return (CGFloat(index) + 0.5) * dayWidth
    }

    private func y(for mood: Double, size: CGSize) -> CGFloat {
        let usable = size.height - verticalPadding * 2
        return verticalPadding + CGFloat(1 - MoodScale.normalized(mood)) * usable
    }

    private func point(for average: (dayIndex: Int, mood: Double, flavour: Double), size: CGSize) -> CGPoint {
        CGPoint(x: x(forDayIndex: average.dayIndex, size: size), y: y(for: average.mood, size: size))
    }

    // MARK: - Drawing

    private func drawBaseline(in context: GraphicsContext, size: CGSize) {
        let baselineY = y(for: MoodScale.baseline, size: size)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baselineY))
        path.addLine(to: CGPoint(x: size.width, y: baselineY))
        context.stroke(path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private func drawSeries(in context: GraphicsContext, size: CGSize) {
        let plotted = dailyAverages.map { average in
            (pos: point(for: average, size: size), color: MoodColor.color(mood: average.mood, flavour: average.flavour))
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
                    with: .linearGradient(Gradient(colors: [a.color, b.color]), startPoint: a.pos, endPoint: b.pos),
                    lineWidth: 2
                )
            }
        }

        for p in plotted {
            let rect = CGRect(x: p.pos.x - dotRadius, y: p.pos.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(p.color))
            context.stroke(Path(ellipseIn: rect), with: .color(.tankBorder), lineWidth: 1)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let sample: [MoodEntry] = (0..<10).map { i in
        MoodEntry(
            id: Int64(i),
            mood: Double.random(in: 10...95),
            flavour: Double.random(in: 0...1),
            title: nil,
            note: nil,
            timestamp: calendar.date(byAdding: .hour, value: -i * 6, to: now) ?? now
        )
    }
    WeeklyDiagramView(entries: sample)
        .padding(24)
}
