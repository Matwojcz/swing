import AppKit
import SwiftUI

extension Color {
    /// Matches an appearance-adaptive color pair, mirroring index.html's
    /// `--surface-1` / `--border-strong` CSS custom properties.
    /// Creates an appearance-adaptive colour that switches between light and dark variants based on the system theme.
    init(light: Color, dark: Color) {
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
    }

    static let tankSurface = Color(
        light: Color(red: 0xf4 / 255, green: 0xf3 / 255, blue: 0xef / 255),
        dark: Color(red: 0x2c / 255, green: 0x2c / 255, blue: 0x2a / 255)
    )

    static let tankBorder = Color(
        light: Color(red: 0x44 / 255, green: 0x44 / 255, blue: 0x41 / 255),
        dark: Color(red: 0xb4 / 255, green: 0xb2 / 255, blue: 0xa9 / 255)
    )
}
