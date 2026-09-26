import Foundation

/// Ported from index.html's state label logic. Descriptive only — never
/// present this as a diagnosis or clinical assessment.
enum MoodState {
    static func label(mood: Double, flavour: Double) -> String {
        let flavourTag = flavour < 0.35 ? "calm" : (flavour > 0.65 ? "irritable" : "normal")
        if mood < 8 { return "depressive" }
        if mood < 20 { return "low, heading depressive" }
        if mood < 45 { return "low" }
        if mood <= 55 { return "baseline" }
        if mood < 75 { return "elevated" }
        if mood < 88 { return "high, \(flavourTag)" }
        return "hype phase, \(flavourTag)"
    }
}
