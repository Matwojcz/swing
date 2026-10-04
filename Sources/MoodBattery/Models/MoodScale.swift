import Foundation

enum MoodScale {
    static let min: Double = 0
    static let max: Double = 10
    static let baseline: Double = 5
    static let step: Double = 0.5
    static let range: ClosedRange<Double> = min...max
    static let redline: Double = 8.8
    static let episodeDepressiveThreshold: Double = 3.5
    static let episodeElevatedThreshold: Double = 6.5

    // Episode rules, modelled on DSM-5 bipolar II: a major depressive episode lasts at least
    // 2 weeks, a hypomanic episode at least 4 days.
    static let episodeDepressiveMinDays = 14
    static let episodeElevatedMinDays = 4
    /// Share of the episode's span that must be logged days past the threshold.
    static let episodeMinQualifyingShare = 0.7
    /// A depressive run tolerates logged days up to this mood (baseline or slightly up); higher ends it.
    static let episodeDepressiveToleratedMax: Double = 5.5
    /// A hypomanic run tolerates logged days down to this mood (baseline or slightly down); lower ends it.
    static let episodeElevatedToleratedMin: Double = 4.5
    /// Most consecutive non-qualifying days (tolerated or unlogged) a run may bridge.
    static let episodeDepressiveMaxGapDays = 2
    static let episodeElevatedMaxGapDays = 2

    /// Formats a mood value for display, dropping the decimal when it's a whole number.
    static func format(_ mood: Double) -> String {
        mood.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(mood))" : String(format: "%.1f", mood)
    }

    /// Maps a mood value to the 0...1 range for use in geometry calculations.
    static func normalized(_ mood: Double) -> Double {
        mood / max
    }

    /// Maps a 0...1 flavour value to its user-facing label: "calm", "normal", or "irritable".
    static func flavourLabel(_ flavour: Double) -> String {
        if flavour < 0.35 { return "calm" }
        if flavour > 0.65 { return "irritable" }
        return "normal"
    }
}
