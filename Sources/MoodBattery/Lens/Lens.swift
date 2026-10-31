import Foundation

/// An opt-in framing that rewords the same data for a condition. The neutral core (`.none`) is the default;
/// a lens never changes stored values, only the words shown for them. See `docs/AI_TAGGING_PLAN.md` §4a.
enum Lens: String, CaseIterable, Identifiable {
    case none, bipolar, pmdd

    /// UserDefaults key for the selected lens, shared by every view that shows a mood label.
    static let storageKey = "lens"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: "Everyday words"
        case .bipolar: "Bipolar lens"
        case .pmdd: "PMDD lens"
        }
    }
}
