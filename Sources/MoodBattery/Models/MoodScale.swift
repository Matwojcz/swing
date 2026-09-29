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

    static func format(_ mood: Double) -> String {
        mood.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(mood))" : String(format: "%.1f", mood)
    }

    static func normalized(_ mood: Double) -> Double {
        mood / max
    }
}
