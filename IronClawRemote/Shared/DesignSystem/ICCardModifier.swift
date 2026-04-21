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

struct ConsoleBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
