import SwiftUI

/// Sparks flying outward from the needle tip once energy crosses the
/// redline threshold. Positions are deterministic (index-based) rather
/// than randomized so the animation is reproducible, matching SpillView's
/// approach for the tank's old overflow effect.
struct GaugeSparkView: View {
    let color: Color
    let tip: CGPoint
    let directionDegrees: Double

    private let sparkCount = 5
    private let cycleDuration: Double = 0.55
    private let sparkDiameter: CGFloat = 5
    private let angleOffsets: [Double] = [-25, -10, 0, 10, 25]
    private let distances: [CGFloat] = [30, 38, 34, 42, 46]

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, _ in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                for i in 0..<sparkCount {
                    let slot = Double(i) / Double(sparkCount)
                    let phase = (elapsed / cycleDuration + slot)
                        .truncatingRemainder(dividingBy: 1)
                    let angle = (directionDegrees + angleOffsets[i]) * .pi / 180
                    let dist = distances[i] * CGFloat(phase)
                    let x = tip.x + cos(angle) * dist
                    let y = tip.y - sin(angle) * dist
                    let opacity = 1 - phase
                    let rect = CGRect(
                        x: x - sparkDiameter / 2,
                        y: y - sparkDiameter / 2,
                        width: sparkDiameter,
                        height: sparkDiameter
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
