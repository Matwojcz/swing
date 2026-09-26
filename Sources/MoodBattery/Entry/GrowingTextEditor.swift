import SwiftUI

struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""

    @State private var textHeight: CGFloat = 28

    private let minHeight: CGFloat = 28
    private let maxHeight: CGFloat = 160
    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                    .padding(.horizontal, horizontalPadding + 4)
                    .padding(.vertical, verticalPadding + 2)
            }

            Text(text.isEmpty ? " " : text)
                .font(.system(size: 13))
                .padding(.horizontal, horizontalPadding + 4)
                .padding(.vertical, verticalPadding + 2)
                .opacity(0)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HeightKey.self, value: geo.size.height)
                })

            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .scrollDisabled(textHeight <= maxHeight)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(height: max(minHeight, min(textHeight, maxHeight)))
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.tankSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.tankBorder.opacity(0.3), lineWidth: 1)
        )
        .onPreferenceChange(HeightKey.self) { textHeight = $0 }
    }

    private struct HeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 28
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}

#Preview {
    VStack {
        GrowingTextEditor(text: .constant(""), placeholder: "Note (optional)")
        GrowingTextEditor(text: .constant("Short note"))
        GrowingTextEditor(text: .constant("A longer note that spans multiple lines to demonstrate the auto-growing behavior of this text editor component"))
    }
    .padding()
    .frame(width: 400)
}
