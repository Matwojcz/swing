import SwiftUI

/// Drops overflowing the top of the tank, representing a hype phase that
/// exceeds normal range. Positions are deterministic (index-based) rather
/// than randomized so the animation is reproducible.
struct SpillView: View {
    let color: Color

    private let dropCount = 4
    private let cycleDuration: Double = 0.9
    private let dropDiameter: CGFloat = 8
    private let horizontalSlots: [Double] = [0.3, 0.65, 0.45, 0.8]

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                for i in 0..<dropCount {
                    let slot = Double(i) / Double(dropCount)
                    let phase = (elapsed / cycleDuration + slot)
                        .truncatingRemainder(dividingBy: 1)
                    let y = size.height * phase
                    let opacity = 1 - phase
                    let x = size.width * horizontalSlots[i]
                    let rect = CGRect(
                        x: x - dropDiameter / 2,
                        y: y - dropDiameter / 2,
                        width: dropDiameter,
                        height: dropDiameter
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
