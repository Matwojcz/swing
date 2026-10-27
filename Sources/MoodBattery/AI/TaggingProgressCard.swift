import SwiftUI

/// Floating card shown while the tagger runs: a moving bar for a single entry, a counting bar with time
/// left and Cancel for a whole-history pass. The app stays usable underneath.
struct TaggingProgressCard: View {
    let controller: TaggingController

    private var title: String {
        if controller.isLoadingModel { return "Loading the tagging model…" }
        switch controller.activity {
        case .single: return "Auto-tagging this entry…"
        case .batch: return "Auto-tagging your entries"
        case .idle: return ""
        }
    }

    private var fraction: Double? {
        guard !controller.isLoadingModel, case .batch(let done, let total) = controller.activity, total > 0 else { return nil }
        return Double(done) / Double(total)
    }

    private var detail: String? {
        if controller.isLoadingModel { return "Only the first run takes this extra step." }
        guard case .batch(let done, let total) = controller.activity else { return "Reading the note on this Mac." }
        let left = controller.secondsRemaining.map { " · \(Self.durationText($0)) left" } ?? ""
        return "\(done) of \(total)\(left)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                if case .batch = controller.activity {
                    Button("Cancel") { controller.cancelBatch() }
                        .controlSize(.small)
                }
            }
            if let fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .frame(width: 340)
        .modifier(GlassContainerModifier(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
    }

    /// "about 3 min", "less than a minute" — coarse on purpose, the per-entry time varies.
    static func durationText(_ seconds: Double) -> String {
        if seconds < 60 { return "less than a minute" }
        let minutes = Int((seconds / 60).rounded())
        return "about \(minutes) min"
    }
}
