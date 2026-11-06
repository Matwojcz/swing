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

    /// The names search finds the day by in the given lens: its band, without flavour or cycle-day text ("very low",
    /// "hypomania"). A Bipolar balanced day at an edge also has "balanced lifted" or "balanced dipping", and the PMDD lens
    /// adds the cycle phase ("premenstrual") when a cycle is logged. Built from the same bands as `label`.
    static func searchNames(mood: Double, lens: Lens, cycle: CycleCalendar.Position? = nil) -> [String] {
        switch lens {
        case .none:
            return [neutralBand(mood)]
        case .bipolar:
            let (band, edge) = bipolarBand(mood)
            return [band] + (edge.map { ["\(band) \($0)"] } ?? [])
        case .pmdd:
            return [pmddLowWord(mood) ?? neutralBand(mood)] + (cycle.map { [$0.phase.rawValue] } ?? [])
        }
    }

    /// Every name `searchNames` can give in the lens, so a search for a two-word name ("very low") reads it as one.
    static func allSearchNames(lens: Lens) -> Set<String> {
        let phases = [CycleCalendar.Phase.period, .follicular, .luteal, .premenstrual]
            .map { CycleCalendar.Position(day: 1, phase: $0) }
        var names = Set<String>()
        for tenth in 0...100 {
            let mood = Double(tenth) / 10
            names.formUnion(searchNames(mood: mood, lens: lens))
            if lens == .pmdd {
                for phase in phases { names.formUnion(searchNames(mood: mood, lens: lens, cycle: phase)) }
            }
        }
        return names
    }

    /// Neutral words only: clinical terms belong to the opt-in Bipolar lens.
    private static func neutralBand(_ mood: Double) -> String {
        if mood < 1.5 { return "very low" }
        if mood < 3 { return "low" }
        if mood < 4.5 { return "dipping" }
        if mood <= 5.5 { return "balanced" }
        if mood < 7 { return "lifted" }
        if mood < 8.5 { return "high" }
        return "very high"
    }

    /// The neutral band, with the flavour on high days.
    private static func neutralLabel(mood: Double, flavour: Double) -> String {
        let band = neutralBand(mood)
        return mood < 7 ? band : "\(band), \(MoodScale.flavourLabel(flavour))"
    }

    /// Bands of the Bipolar UK Mood Scale (0-1 severe depression, 2-3 mild to moderate depression, 4-6 balanced,
    /// 7-8 hypomania, 9-10 mania), read at the nearest whole number, so 8.5 and up is mania. 3 is the mild end, 2 the moderate.
    /// The wide balanced band keeps the everyday "dipping" and "lifted" at its edges, so switching lens never changes how the day reads.
    private static func bipolarBand(_ mood: Double) -> (band: String, edge: String?) {
        switch Int(mood.rounded()) {
        case ...1: ("severe depression", nil)
        case 2: ("moderate depression", nil)
        case 3: ("mild depression", nil)
        case 4...6: ("balanced", mood < 4.5 ? "dipping" : mood > 5.5 ? "lifted" : nil)
        case 7...8: ("hypomania", nil)
        default: ("mania", nil)
        }
    }

    /// The Bipolar band, with its edge on balanced days and the flavour on hypomania and mania.
    private static func bipolarLabel(mood: Double, flavour: Double) -> String {
        let (band, edge) = bipolarBand(mood)
        if let edge { return "\(band), \(edge)" }
        return mood.rounded() >= 7 ? "\(band), \(MoodScale.flavourLabel(flavour))" : band
    }

    /// The PMDD lens's word for a low day, nil from 4.5 up.
    private static func pmddLowWord(_ mood: Double) -> String? {
        mood < 1.5 ? "very low mood" : mood < 3 ? "low mood" : mood < 4.5 ? "dip" : nil
    }

    /// Places the day in the cycle. A low or irritable day in the premenstrual week or the first days of a period reads
    /// as cycle-linked, the same day elsewhere as non-cycle related, since PMDD is defined by that timing.
    private static func pmddLabel(mood: Double, flavour: Double, cycle: CycleCalendar.Position?) -> String {
        let lowWord = pmddLowWord(mood)
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
