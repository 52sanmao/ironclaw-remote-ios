import SwiftUI

struct ICCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(ICSpacing.md)
            .background(ICColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func icCard() -> some View {
        modifier(ICCardModifier())
    }
}
