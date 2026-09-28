import SwiftUI

/// Ported from index.html's colorAt(): black at the depressive floor, through
/// purple, up to blue at baseline; above baseline blends toward happy gold/orange
/// or irritable red/magenta depending on flavour.
enum MoodColor {
    private typealias Stop = (value: Double, rgb: (Double, Double, Double))

    private static let lowStops: [Stop] = [
        (0, (18, 18, 18)),
        (20, (83, 74, 183)),
        (50, (55, 138, 221)),
    ]
    private static let happyHighStops: [Stop] = [
        (50, (55, 138, 221)),
        (62, (72, 178, 120)),
        (75, (239, 159, 39)),
        (100, (216, 90, 48)),
    ]
    private static let irritableHighStops: [Stop] = [
        (50, (55, 138, 221)),
        (62, (88, 160, 110)),
        (75, (226, 75, 74)),
        (100, (153, 53, 86)),
    ]

    /// - Parameters:
    ///   - mood: 0...100, baseline at 50.
    ///   - flavour: 0...1, 0 = happy hype, 1 = irritable hype.
    static func color(mood: Double, flavour: Double) -> Color {
        let rgb: (Double, Double, Double)
        if mood <= 50 {
            rgb = interp(lowStops, mood)
        } else {
            let happy = interp(happyHighStops, mood)
            let irritable = interp(irritableHighStops, mood)
            rgb = (
                lerp(happy.0, irritable.0, flavour),
                lerp(happy.1, irritable.1, flavour),
                lerp(happy.2, irritable.2, flavour)
            )
        }
        return Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func interp(_ stops: [Stop], _ v: Double) -> (Double, Double, Double) {
        var lo = stops[0]
        var hi = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) where v >= stops[i].value && v <= stops[i + 1].value {
            lo = stops[i]
            hi = stops[i + 1]
            break
        }
        let span = hi.value - lo.value == 0 ? 1 : hi.value - lo.value
        let t = (v - lo.value) / span
        return (
            lerp(lo.rgb.0, hi.rgb.0, t),
            lerp(lo.rgb.1, hi.rgb.1, t),
            lerp(lo.rgb.2, hi.rgb.2, t)
        )
    }
}
