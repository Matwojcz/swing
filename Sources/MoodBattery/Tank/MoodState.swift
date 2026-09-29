import Foundation

/// Descriptive only — never present this as a diagnosis or clinical assessment.
enum MoodState {
    /// Returns a human-readable band label (e.g. "baseline", "elevated", "high, irritable") for the given mood and flavour values.
    static func label(mood: Double, flavour: Double) -> String {
        let flavourTag = MoodScale.flavourLabel(flavour)
        if mood < 1.5 { return "severe depressive" }
        if mood < 3 { return "depressive" }
        if mood < 4.5 { return "low" }
        if mood <= 5.5 { return "baseline" }
        if mood < 7 { return "elevated" }
        if mood < 8.5 { return "high, \(flavourTag)" }
        return "hyper, \(flavourTag)"
    }
}
