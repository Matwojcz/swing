import SwiftUI

/// The lens switch, drawn as a microscope's revolving nosepiece: one objective per lens around a disc.
/// Clicking turns the disc forward until the next objective sits at the top, and that lens is selected.
/// Hovering shows the selected lens's name under the disc.
struct LensTurret: View {
    @Binding var lens: Lens
    /// Accumulated so the disc always turns the same way, even when it wraps from the last lens to the first.
    @State private var rotation: Double?
    @State private var isHovering = false

    private static let step = 360 / Double(Lens.allCases.count)
    /// Also the loupe ring's height, so the two outlines line up beside each other.
    static let size: CGFloat = 22
    static let outlineWidth: CGFloat = 1.5
    static let outlineColor = Color.secondary.opacity(0.6)
    private static let objectiveSize: CGFloat = 6
    /// Distance of each objective's centre from the disc's centre.
    private static let orbit: CGFloat = 5.5

    var body: some View {
        Button(action: turn) {
            ZStack {
                Circle()
                    .stroke(Self.outlineColor, lineWidth: Self.outlineWidth)
                ForEach(Array(Lens.allCases.enumerated()), id: \.element) { index, item in
                    Circle()
                        .fill(item == lens ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: Self.objectiveSize, height: Self.objectiveSize)
                        .offset(y: -Self.orbit)
                        .rotationEffect(.degrees(Double(index) * Self.step))
                }
            }
            .rotationEffect(.degrees(rotation ?? restingRotation))
            .frame(width: Self.size, height: Self.size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        // Drawn outside the layout so the label beside the turret doesn't move when it appears.
        .overlay(alignment: .top) {
            if isHovering {
                Text(lens.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(y: Self.size + 4)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .help("Click to turn to the next lens")
        .accessibilityLabel("Lens")
        .accessibilityValue(lens.name)
    }

    /// The angle that brings the selected lens's objective to the top.
    private var restingRotation: Double {
        -Double(Lens.allCases.firstIndex(of: lens) ?? 0) * Self.step
    }

    private func turn() {
        let lenses = Lens.allCases
        let next = lenses[((lenses.firstIndex(of: lens) ?? 0) + 1) % lenses.count]
        let current = rotation ?? restingRotation
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            rotation = current - Self.step
            lens = next
        }
    }
}

/// A view modifier for the lens word changing: blurred, faded and scaled while it goes in or out of focus.
private struct FocusModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}

extension AnyTransition {
    /// The old word blurs out and the new one sharpens into place, like racking the focus on a microscope.
    static var focusPull: AnyTransition {
        let sharp = FocusModifier(blur: 0, opacity: 1, scale: 1)
        return .asymmetric(
            insertion: .modifier(active: FocusModifier(blur: 6, opacity: 0, scale: 1.15), identity: sharp),
            removal: .modifier(active: FocusModifier(blur: 6, opacity: 0, scale: 0.9), identity: sharp)
        )
    }
}
