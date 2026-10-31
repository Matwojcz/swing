import Foundation

/// Descriptive only — never present this as a diagnosis or clinical assessment.
enum MoodState {
    /// Returns a human-readable band label (e.g. "balanced", "lifted", "high, irritable") for the given mood and flavour values.
    /// Neutral words only: clinical terms belong to the opt-in Bipolar lens.
    static func label(mood: Double, flavour: Double) -> String {
        let flavourTag = MoodScale.flavourLabel(flavour)
        if mood < 1.5 { return "very low" }
        if mood < 3 { return "low" }
        if mood < 4.5 { return "dipping" }
        if mood <= 5.5 { return "balanced" }
        if mood < 7 { return "lifted" }
        if mood < 8.5 { return "high, \(flavourTag)" }
        return "very high, \(flavourTag)"
    }
}
