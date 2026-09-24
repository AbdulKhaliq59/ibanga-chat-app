import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    var transferProgress: Double?
    var loadThumbnail: (Attachment) async -> CGImage? = { _ in nil }
    var onOpenAttachment: (Attachment) -> Void = { _ in }
    var onRetry: () -> Void = {}

    private var isOutgoing: Bool { message.direction == .outgoing }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOutgoing { Spacer(minLength: IbangaSpacing.xxxl) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: IbangaSpacing.xs) {
                content
                    .contextMenu { contextMenu }

                if isLastInGroup || message.status == .failed || transferProgress != nil {
                    metadata
                        .padding(.horizontal, IbangaSpacing.xs)
                }
            }

            if !isOutgoing { Spacer(minLength: IbangaSpacing.xxxl) }
        }
        .padding(.top, isFirstInGroup ? IbangaSpacing.s : 0)
    }

    @ViewBuilder
    private var content: some View {
        switch message.content {
        case .text(let text):
            Text(text)
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityPrefix + Text(text))

        case .attachment(let attachment):
            Button {
                onOpenAttachment(attachment)
            } label: {
                if attachment.kind == .image {
                    ImageAttachmentView(attachment: attachment, progress: transferProgress, loadImage: loadThumbnail)
                } else {
                    FileAttachmentView(attachment: attachment, isOutgoing: isOutgoing, progress: transferProgress)
                        .background(bubbleShape.fill(isOutgoing ? IbangaColors.accent : IbangaColors.surface))
                        .overlay {
                            if !isOutgoing {
                                bubbleShape.strokeBorder(IbangaColors.separator, lineWidth: 0.5)
                            }
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(transferProgress != nil)
            .accessibilityHint(attachment.kind == .image ? "Opens the photo" : "Opens the file")
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if let text = message.text {
            Button("Copy", systemImage: IbangaIcons.copy) {
                UIPasteboard.general.string = text
            }
        }
        if message.status == .failed {
            Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: IbangaSpacing.xs) {
            if let transferProgress {
                Image(systemName: IbangaIcons.lockFilled)
                    .accessibilityHidden(true)
                Text("Encrypting and sending \(transferProgress, format: .percent.precision(.fractionLength(0)))")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } else {
                Text(message.sentAt, format: .dateTime.hour().minute())
                if isOutgoing, let status = statusText {
                    Text("·")
                    Text(status)
                        .foregroundStyle(message.status == .failed ? IbangaColors.danger : IbangaColors.textTertiary)
                }
                if message.status == .failed {
                    Button("Retry", action: onRetry)
                        .font(IbangaTypography.caption.weight(.semibold))
                        .tint(IbangaColors.accent)
                }
            }
        }
        .font(IbangaTypography.caption)
        .foregroundStyle(IbangaColors.textTertiary)
        .animation(.easeOut(duration: 0.2), value: transferProgress)
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

    private var accessibilityPrefix: Text {
        let sender = isOutgoing ? Text("You") : Text("Received")
        let time = Text(message.sentAt, format: .dateTime.hour().minute())
        if isOutgoing, let status = statusText {
            return sender + Text(", ") + time + Text(", ") + Text(status) + Text(": ")
        }
        return sender + Text(", ") + time + Text(": ")
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
}

#Preview {
    VStack {
        MessageBubble(
            message: Message(
                id: UUID(), conversationID: UUID(), senderID: "a", recipientID: "b",
                direction: .outgoing, content: .text("Are you coming?"), sentAt: .now, status: .delivered
            ),
            isFirstInGroup: true,
            isLastInGroup: true
        )
        MessageBubble(
            message: Message(
                id: UUID(), conversationID: UUID(), senderID: "b", recipientID: "a",
                direction: .incoming,
                content: .attachment(Attachment(id: UUID(), kind: .file, filename: "Itinerary.pdf", contentType: "com.adobe.pdf", byteCount: 1_240_000)),
                sentAt: .now, status: .received
            ),
            isFirstInGroup: true,
            isLastInGroup: true
        )
    }
    .padding()
}
