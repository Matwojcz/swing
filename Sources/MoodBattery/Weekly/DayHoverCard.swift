import SwiftUI

/// The small card shown when hovering a dot on the diagram: the day's mood and tags, and a line when the day stands
/// out ("Lowest since 26 Oct"). On the year scale a dot is a week: its average and its lowest and highest day.
struct DayHoverCard: View {
    let date: Date
    /// On the year scale a dot is a week's average.
    let isWeek: Bool
    let mood: Double
    /// The week's lowest and highest day, on the year scale.
    var low: Double? = nil
    var high: Double? = nil
    let label: String
    var tags: [MoodTag] = []
    var record: DayRecord.Result? = nil

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let sinceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let sinceFormatterWithYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(isWeek ? "Week of \(Self.dayFormatter.string(from: date))" : Self.dayFormatter.string(from: date))
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
            if isWeek, let low, let high {
                Text("Days from \(MoodScale.format(low)) to \(MoodScale.format(high))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if !tags.isEmpty {
                MoodTagChips(tags: tags, fontSize: 10)
            }
            if let record {
                Text(recordText(record))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.tankSurface))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    /// "Lowest since 26 Oct", "Highest since you started logging".
    private func recordText(_ record: DayRecord.Result) -> String {
        let word = record.kind == .lowest ? "Lowest" : "Highest"
        guard let since = record.since else { return "\(word) since you started logging" }
        let sameYear = Calendar.current.isDate(since, equalTo: date, toGranularity: .year)
        return "\(word) since \((sameYear ? Self.sinceFormatter : Self.sinceFormatterWithYear).string(from: since))"
    }
}

#Preview {
    DayHoverCard(date: Date(), isWeek: false, mood: 3.6, label: "dipping", tags: [.low, .foggy, .flat],
                 record: .init(kind: .lowest, since: Calendar.current.date(byAdding: .day, value: -20, to: Date())))
        .frame(width: 230)
        .padding()
}
