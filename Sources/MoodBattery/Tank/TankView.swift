import SwiftUI

/// The battery/tank visual: fills and colors from `energy` and `flavour`,
/// with a dashed baseline marker at 50% and overflow drops past 88.
/// Purely display-driven so it can be reused unchanged in the daily entry
/// view and any future weekly/summary view.
struct TankView: View {
    var energy: Double
    var flavour: Double

    private let width: CGFloat = 140
    private let height: CGFloat = 220
    private let cornerRadius: CGFloat = 14
    private let spillThreshold: Double = 88

    private var fillColor: Color {
        MoodColor.color(energy: energy, flavour: flavour)
    }

    var body: some View {
        ZStack {
            cap
            tankBody
            baselineMarker
            if energy >= spillThreshold {
                SpillView(color: fillColor)
                    .frame(width: width, height: 50)
                    .offset(y: -height / 2 - 25)
            }
        }
        .frame(width: width, height: height)
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.tankSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.tankBorder, lineWidth: 2)
            )
            .frame(width: 40, height: 12)
            .offset(y: -height / 2 - 6)
    }

    private var tankBody: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.tankSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(fillColor)
                    .frame(height: height * CGFloat(energy / 100))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.tankBorder, lineWidth: 3)
            )
            .frame(width: width, height: height)
    }

    private var baselineMarker: some View {
        DashedLine()
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [14, 10]))
            .frame(width: width + 32, height: 1)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        TankView(energy: 20, flavour: 0.5)
        TankView(energy: 50, flavour: 0.5)
        TankView(energy: 92, flavour: 0.1)
    }
    .padding(40)
}
