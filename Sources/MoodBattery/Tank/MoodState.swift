import Foundation

/// Ported from index.html's state label logic. Descriptive only — never
/// present this as a diagnosis or clinical assessment.
enum MoodState {
    static func label(energy: Double, flavour: Double) -> String {
        let flavourTag = flavour < 0.35 ? "happy" : (flavour > 0.65 ? "irritable" : "mixed")
        if energy < 8 { return "depressive" }
        if energy < 20 { return "low, heading depressive" }
        if energy < 45 { return "low" }
        if energy <= 55 { return "baseline" }
        if energy < 75 { return "charged up" }
        if energy < 88 { return "high energy, \(flavourTag)" }
        return "hype phase, \(flavourTag)"
    }
}
