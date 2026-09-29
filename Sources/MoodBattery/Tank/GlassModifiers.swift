import SwiftUI

/// Applies liquid glass button style on macOS 26+, falling back to borderedProminent.
struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Wraps a text field in a glass effect on macOS 26+, falling back to a themed surface fill with a subtle border.
struct GlassFieldModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.tankSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.tankBorder.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

/// Gives a container view a glass background on macOS 26+, falling back to a themed surface fill.
struct GlassContainerModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.tankSurface)
                )
        }
    }
}

/// Highlights the selected diagram scale tab with a glass pill on macOS 26+, falling back to a surface fill.
struct GlassScaleTabModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
            } else {
                content
            }
        } else {
            if isSelected {
                content
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.tankSurface)
                    )
            } else {
                content
            }
        }
    }
}
