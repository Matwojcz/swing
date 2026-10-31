import Foundation

/// Descriptive only — never present this as a diagnosis or clinical assessment.
enum MoodState {
    /// Returns a human-readable band label (e.g. "balanced", "lifted", "high, irritable") for the given mood and flavour values,
    /// in the words of the given lens. The PMDD lens also needs the day's place in the cycle, nil when none is logged.
    static func label(mood: Double, flavour: Double, lens: Lens = .none, cycle: CycleCalendar.Position? = nil) -> String {
        switch lens {
        case .none: neutralLabel(mood: mood, flavour: flavour)
        case .bipolar: bipolarLabel(mood: mood, flavour: flavour)
        case .pmdd: pmddLabel(mood: mood, flavour: flavour, cycle: cycle)
        }
    }

    /// Neutral words only: clinical terms belong to the opt-in Bipolar lens.
    private static func neutralLabel(mood: Double, flavour: Double) -> String {
        let flavourTag = MoodScale.flavourLabel(flavour)
        if mood < 1.5 { return "very low" }
        if mood < 3 { return "low" }
        if mood < 4.5 { return "dipping" }
        if mood <= 5.5 { return "balanced" }
        if mood < 7 { return "lifted" }
        if mood < 8.5 { return "high, \(flavourTag)" }
        return "very high, \(flavourTag)"
    }

    /// Bands of the Bipolar UK Mood Scale (0-1 severe depression, 2-3 mild to moderate depression, 4-6 balanced,
    /// 7-8 hypomania, 9-10 mania), read at the nearest whole number, so 8.5 and up is mania. 3 is the mild end, 2 the moderate.
    private static func bipolarLabel(mood: Double, flavour: Double) -> String {
        let flavourTag = MoodScale.flavourLabel(flavour)
        switch Int(mood.rounded()) {
        case ...1: return "severe depression"
        case 2: return "moderate depression"
        case 3: return "mild depression"
        case 4...6: return "balanced"
        case 7...8: return "hypomania, \(flavourTag)"
        default: return "mania, \(flavourTag)"
        }
    }

    /// Places the day in the cycle. A low or irritable day in the premenstrual week or the first days of a period reads
    /// as cycle-linked, the same day elsewhere as non-cycle related, since PMDD is defined by that timing.
    private static func pmddLabel(mood: Double, flavour: Double, cycle: CycleCalendar.Position?) -> String {
        let lowWord: String? = mood < 1.5 ? "very low mood" : mood < 3 ? "low mood" : mood < 4.5 ? "dip" : nil
        let irritable = MoodScale.flavourLabel(flavour) == "irritable"
        let symptom: String? = switch (lowWord, irritable) {
        case (let low?, true): "\(low), irritable"
        case (let low?, false): low
        case (nil, true): "irritability"
        case (nil, false): nil
        }
        guard let cycle else { return "\(symptom ?? neutralLabel(mood: mood, flavour: flavour)) · no cycle logged" }
        guard let symptom else { return "\(neutralLabel(mood: mood, flavour: flavour)) · \(cycle.phase.rawValue) day \(cycle.day)" }
        switch cycle.phase {
        case .premenstrual: return "premenstrual \(symptom) · day \(cycle.day)"
        case .period where cycle.day <= 3: return "\(symptom) · period day \(cycle.day)"
        default: return "\(symptom) · non-cycle related"
        }
    }
}
