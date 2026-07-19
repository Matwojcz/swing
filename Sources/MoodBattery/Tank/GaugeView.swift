import SwiftUI

/// The mood gauge visual: a semicircular dial with a colored band running
/// depressive -> baseline -> hype, a needle pointing at the current energy,
/// a dashed baseline tick at 50, and a "redline" zone with spark particles
/// past the hype threshold. A gauge reads as bounded-with-overshoot rather
/// than a container that overflows, which is why this replaced the tank.
/// Ported from inspiration/mood-gauge.html. Purely display-driven unless
/// `onEnergyChange` is supplied, so it can be reused unchanged in read-only
/// views (history, weekly summary).
struct GaugeView: View {
    var energy: Double
    var flavour: Double
    var onEnergyChange: ((Double) -> Void)? = nil

    /// Reference geometry (from mood-gauge.html) scaled up 20% — the dial
    /// read too small next to the rest of the entry screen.
    static let scale: CGFloat = 1.2
    static let width: CGFloat = 320 * scale
    static let height: CGFloat = 210 * scale
    private static let cx: CGFloat = 160 * scale
    private static let cy: CGFloat = 190 * scale
    private static let innerRadius: CGFloat = 108 * scale
    private static let outerRadius: CGFloat = 138 * scale
    private static let needleLength: CGFloat = 122 * scale
    private static let redlineThreshold: Double = 88
    /// Top of the dashed baseline tick, measured from this view's own top
    /// edge — exposed so sibling layout (the flavour slider) can align to it.
    static let baselineTopY: CGFloat = cy - (outerRadius + 18 * scale)

    private let redlineColor = Color(red: 194 / 255, green: 59 / 255, blue: 58 / 255)
    private var redlineThreshold: Double { Self.redlineThreshold }
    private var width: CGFloat { Self.width }
    private var height: CGFloat { Self.height }
    private var cx: CGFloat { Self.cx }
    private var cy: CGFloat { Self.cy }
    private var innerRadius: CGFloat { Self.innerRadius }
    private var outerRadius: CGFloat { Self.outerRadius }
    private var needleLength: CGFloat { Self.needleLength }

    private var fillColor: Color {
        MoodColor.color(energy: energy, flavour: flavour)
    }

    var body: some View {
        Group {
            if let onEnergyChange {
                gaugeStack
                    .contentShape(Rectangle())
                    .gesture(dragGesture(onEnergyChange))
            } else {
                gaugeStack
            }
        }
    }

    private var gaugeStack: some View {
        ZStack {
            Canvas { context, _ in
                drawBand(in: context)
                drawBaselineTick(in: context)
                drawRedlineTicks(in: context)
                drawNeedle(in: context)
                drawHub(in: context)
            }
            .frame(width: width, height: height)

            if energy >= redlineThreshold {
                GaugeSparkView(
                    color: fillColor,
                    tip: point(for: energy, radius: needleLength),
                    directionDegrees: angleDegrees(for: energy)
                )
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Geometry

    private func angleDegrees(for value: Double) -> Double {
        180 - (value / 100) * 180
    }

    private func point(for value: Double, radius: CGFloat) -> CGPoint {
        let theta = angleDegrees(for: value) * .pi / 180
        return CGPoint(x: cx + radius * cos(theta), y: cy - radius * sin(theta))
    }

    // MARK: - Drawing

    private func drawBand(in context: GraphicsContext) {
        let ticks = 100
        for i in 0...ticks {
            let v = Double(i) / Double(ticks) * 100
            var path = Path()
            path.move(to: point(for: v, radius: innerRadius))
            path.addLine(to: point(for: v, radius: outerRadius))
            context.stroke(path, with: .color(MoodColor.color(energy: v, flavour: flavour)), lineWidth: 3 * Self.scale)
        }
    }

    private func drawBaselineTick(in context: GraphicsContext) {
        var path = Path()
        path.move(to: point(for: 50, radius: innerRadius - 14))
        path.addLine(to: point(for: 50, radius: outerRadius + 18))
        context.stroke(
            path,
            with: .color(.white.opacity(0.9)),
            style: StrokeStyle(lineWidth: 1 * Self.scale, dash: [4 * Self.scale, 4 * Self.scale])
        )
    }

    private func drawRedlineTicks(in context: GraphicsContext) {
        let steps = 24
        for i in 0...steps {
            let v = redlineThreshold + Double(i) / Double(steps) * 12
            var path = Path()
            path.move(to: point(for: v, radius: outerRadius + 5))
            path.addLine(to: point(for: v, radius: outerRadius + 15))
            context.stroke(path, with: .color(redlineColor), lineWidth: 2.5 * Self.scale)
        }
    }

    private func drawNeedle(in context: GraphicsContext) {
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy))
        path.addLine(to: point(for: energy, radius: needleLength))
        let strokeColor: Color = energy >= redlineThreshold
            ? Color(red: 242 / 255, green: 240 / 255, blue: 233 / 255)
            : Color(red: 232 / 255, green: 230 / 255, blue: 223 / 255)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3 * Self.scale, lineCap: .round))
    }

    private func drawHub(in context: GraphicsContext) {
        let hubRadius = 9 * Self.scale
        let rect = CGRect(x: cx - hubRadius, y: cy - hubRadius, width: hubRadius * 2, height: hubRadius * 2)
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(fillColor))
        context.stroke(path, with: .color(.tankBorder), lineWidth: 2 * Self.scale)
    }

    // MARK: - Drag

    private func dragGesture(_ onEnergyChange: @escaping (Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = Double(value.location.x - cx)
                let dy = Double(value.location.y - cy)
                var angleDeg = atan2(-dy, dx) * 180 / Double.pi
                if angleDeg < 0 {
                    angleDeg = dx >= 0 ? 0 : 180
                }
                onEnergyChange(((180 - angleDeg) / 180 * 100).rounded())
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        GaugeView(energy: 20, flavour: 0.5)
        GaugeView(energy: 50, flavour: 0.5)
        GaugeView(energy: 92, flavour: 0.1)
    }
    .padding(40)
}
