import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isFirstInGroup: Bool
    let isLastInGroup: Bool

    private var isOutgoing: Bool { message.direction == .outgoing }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOutgoing { Spacer(minLength: IbangaSpacing.xxxl) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: IbangaSpacing.xs) {
                Text(message.text)
                    .font(IbangaTypography.body)
                    .foregroundStyle(isOutgoing ? IbangaColors.onAccent : IbangaColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(bubbleShape.fill(isOutgoing ? IbangaColors.accent : IbangaColors.surface))
                    .overlay {
                        if !isOutgoing {
                            bubbleShape.strokeBorder(IbangaColors.separator, lineWidth: 0.5)
                        }
                    }
                    .contextMenu {
                        Button("Copy", systemImage: IbangaIcons.copy) {
                            UIPasteboard.general.string = message.text
                        }
                    }

                if isLastInGroup || message.status == .failed {
                    metadata
                        .padding(.horizontal, IbangaSpacing.xs)
                }
            }

            if !isOutgoing { Spacer(minLength: IbangaSpacing.xxxl) }
        }
        .padding(.top, isFirstInGroup ? IbangaSpacing.s : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var metadata: some View {
        HStack(spacing: IbangaSpacing.xs) {
            Text(message.sentAt, format: .dateTime.hour().minute())
            if isOutgoing, let status = statusText {
                Text("·")
                Text(status)
                    .foregroundStyle(message.status == .failed ? IbangaColors.danger : IbangaColors.textTertiary)
            }
        }
        .font(IbangaTypography.caption)
        .foregroundStyle(IbangaColors.textTertiary)
    }

    private var statusText: LocalizedStringKey? {
        switch message.status {
        case .sending: "Sending…"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .failed: "Not sent"
        case .received: nil
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let large: CGFloat = 18
        let small: CGFloat = 6
        return UnevenRoundedRectangle(
            topLeadingRadius: !isOutgoing && !isFirstInGroup ? small : large,
            bottomLeadingRadius: !isOutgoing && !isLastInGroup ? small : large,
            bottomTrailingRadius: isOutgoing && !isLastInGroup ? small : large,
            topTrailingRadius: isOutgoing && !isFirstInGroup ? small : large,
            style: .continuous
        )
    }

    private var accessibilityText: Text {
        let sender = isOutgoing ? Text("You") : Text("Received")
        let time = Text(message.sentAt, format: .dateTime.hour().minute())
        if isOutgoing, let status = statusText {
            return sender + Text(": ") + Text(message.text) + Text(", ") + time + Text(", ") + Text(status)
        }
        return sender + Text(": ") + Text(message.text) + Text(", ") + time
    }
}

#Preview {
    let message = Message(
        id: UUID(), conversationID: UUID(), senderID: "a", recipientID: "b",
        direction: .outgoing, content: .text("Are you coming?"), sentAt: .now, status: .delivered
    )
    VStack {
        MessageBubble(message: message, isFirstInGroup: true, isLastInGroup: true)
    }
    .padding()
}
