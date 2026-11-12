import SwiftUI

/// The small card shown when hovering a dot on the diagram: the day's mood and the 30 days before and after it.
/// Worded as what the numbers were, never why.
struct DayHoverCard: View {
    let date: Date
    /// On the year scale a dot is a week's average.
    let isWeek: Bool
    let mood: Double
    let label: String
    let comparison: DayComparison

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(isWeek ? "Week of \(Self.dateFormatter.string(from: date))" : Self.dateFormatter.string(from: date))
                    .font(.system(size: 11, weight: .semibold))
                Spacer(minLength: 4)
                Text(MoodScale.format((mood * 10).rounded() / 10))
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(MoodColor.color(mood: mood, flavour: 0.3))
                    .lineLimit(1)
            }
            row(title: "\(DayComparison.windowDays) days before", window: comparison.before)
            if comparison.after.days == 0 {
                Text("Nothing after yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                row(title: comparison.after.days < DayComparison.windowDays
                        ? "\(comparison.after.days) \(comparison.after.days == 1 ? "day" : "days") after, to today"
                        : "\(DayComparison.windowDays) days after",
                    window: comparison.after)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.tankSurface))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    private func row(title: String, window: DayComparison.Window) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(window.averageMood.map { String(format: "%.1f", $0) } ?? "–")
                .fontWeight(.medium)
            Text(window.loggedDays == 0 ? "nothing logged" : "\(window.loggedDays) logged")
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 11))
        .monospacedDigit()
    }
}

#Preview {
    DayHoverCard(
        date: Date(), isWeek: false, mood: 6.2, label: "lifted",
        comparison: DayComparison(
            before: .init(days: 30, loggedDays: 29, averageMood: 5.0, elevatedDays: 2, lowDays: 1),
            after: .init(days: 12, loggedDays: 11, averageMood: 4.6, elevatedDays: 0, lowDays: 1)
        )
    )
    .padding()
}
