import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let canSend: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: IbangaSpacing.s) {
            TextField("Message", text: $text, axis: .vertical)
                .font(IbangaTypography.body)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(IbangaColors.surface, in: .rect(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
                }

            Button(action: onSend) {
                Image(systemName: IbangaIcons.send)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(IbangaColors.onAccent)
                    .frame(width: 36, height: 36)
                    .background(canSend ? IbangaColors.accent : IbangaColors.neutral, in: .circle)
            }
            .disabled(!canSend)
            .padding(.bottom, 2)
            .animation(.easeOut(duration: 0.15), value: canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, IbangaSpacing.m)
        .padding(.vertical, IbangaSpacing.s)
        .background(.bar)
    }
}

#Preview {
    VStack {
        Spacer()
        MessageComposer(text: .constant("Are you coming?"), canSend: true) {}
    }
}
