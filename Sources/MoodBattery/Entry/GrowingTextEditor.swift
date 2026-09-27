import SwiftUI

struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: String = ""

    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 6

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: 32, maxHeight: 160)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 13))
                        .padding(.horizontal, horizontalPadding + 4)
                        .padding(.vertical, verticalPadding + 2)
                        .allowsHitTesting(false)
                }
            }
            .modifier(GlassFieldModifier())
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
