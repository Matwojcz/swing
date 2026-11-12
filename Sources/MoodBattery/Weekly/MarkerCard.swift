import SwiftUI

/// The popover for a marker: the 30 days before and after it side by side, with edit and delete.
/// Worded as what changed around the date, never why.
struct MarkerCard: View {
    let marker: DiagramMarker
    let comparison: MarkerComparison
    var onEdit: () -> Void
    var onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: marker.kind.symbol)
                    .foregroundStyle(.secondary)
                Text(marker.label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let day = marker.day() {
                    Text(Self.dateFormatter.string(from: day))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                tile(title: "\(MarkerComparison.windowDays) days before", window: comparison.before)
                tile(title: comparison.after.days < MarkerComparison.windowDays
                        ? "\(comparison.after.days) \(comparison.after.days == 1 ? "day" : "days") from this day"
                        : "\(MarkerComparison.windowDays) days from this day",
                     window: comparison.after)
            }

            HStack {
                Button("Delete", role: .destructive, action: onDelete)
                    .controlSize(.small)
                Spacer()
                Button("Edit", action: onEdit)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 380)
    }

    private func tile(title: String, window: MarkerComparison.Window) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(window.averageMood.map { String(format: "%.1f", $0) } ?? "–")
                .font(.system(size: 20, weight: .medium))
                .monospacedDigit()
            Text(window.loggedDays == 0 ? "nothing logged"
                 : "average of \(window.loggedDays) logged \(window.loggedDays == 1 ? "day" : "days")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Group {
                Text("\(window.elevatedDays) \(window.elevatedDays == 1 ? "day" : "days") at 6.5 or above")
                Text("\(window.lowDays) \(window.lowDays == 1 ? "day" : "days") below 3.5")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.tankSurface))
    }
}

#Preview {
    MarkerCard(
        marker: DiagramMarker(id: 1, localDate: "2026-09-11", label: "Quetiapine 150 mg", kind: .medication),
        comparison: MarkerComparison(
            before: .init(days: 30, loggedDays: 27, averageMood: 5.6, elevatedDays: 6, lowDays: 1),
            after: .init(days: 30, loggedDays: 30, averageMood: 4.8, elevatedDays: 0, lowDays: 2)
        ),
        onEdit: {}, onDelete: {}
    )
}
