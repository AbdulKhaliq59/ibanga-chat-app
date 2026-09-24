import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let canSend: Bool
    var pendingAttachment: AttachmentDraft?
    var pendingThumbnail: CGImage?
    var isPreparingAttachment = false
    var onAddAttachment: () -> Void = {}
    var onRemoveAttachment: () -> Void = {}
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: IbangaSpacing.s) {
            if let pendingAttachment {
                AttachmentPreviewCard(attachment: pendingAttachment, thumbnail: pendingThumbnail, onRemove: onRemoveAttachment)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: IbangaSpacing.s) {
                Button(action: onAddAttachment) {
                    Group {
                        if isPreparingAttachment {
                            ProgressView()
                        } else {
                            Image(systemName: IbangaIcons.plus)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(IbangaColors.accent)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(IbangaColors.accentSoft, in: .circle)
                }
                .disabled(isPreparingAttachment)
                .padding(.bottom, 2)
                .accessibilityLabel("Add attachment")

                TextField("Message", text: $text, axis: .vertical)
                    .font(IbangaTypography.body)
                    .lineLimit(1...5)
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
                        .scaleEffect(canSend ? 1 : 0.92)
                }
                .disabled(!canSend)
                .padding(.bottom, 2)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, IbangaSpacing.m)
        .padding(.vertical, IbangaSpacing.s)
        .background(.bar)
        .animation(.easeOut(duration: 0.15), value: canSend)
        .animation(.easeOut(duration: 0.2), value: pendingAttachment)
        .sensoryFeedback(.impact(weight: .light), trigger: pendingAttachment != nil) { _, isAttached in isAttached }
    }
}

#Preview {
    VStack {
        Spacer()
        MessageComposer(
            text: .constant("Are you coming?"),
            canSend: true,
            pendingAttachment: AttachmentDraft(kind: .file, filename: "Itinerary.pdf", contentType: "com.adobe.pdf", data: Data(count: 1_240_000))
        ) {}
    }
}
