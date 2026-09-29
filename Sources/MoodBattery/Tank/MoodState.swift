import Foundation

/// Descriptive only — never present this as a diagnosis or clinical assessment.
enum MoodState {
    static func label(mood: Double, flavour: Double) -> String {
        let flavourTag = flavour < 0.35 ? "calm" : (flavour > 0.65 ? "irritable" : "normal")
        if mood < 1.5 { return "severe depressive" }
        if mood < 3 { return "depressive" }
        if mood < 4.5 { return "low" }
        if mood <= 5.5 { return "baseline" }
        if mood < 7 { return "elevated" }
        if mood < 8.5 { return "high, \(flavourTag)" }
        return "hyper, \(flavourTag)"
    }
}
