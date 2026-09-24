import SwiftUI

/// The attachment waiting in the composer, before it is encrypted and sent.
struct AttachmentPreviewCard: View {
    let attachment: AttachmentDraft
    let thumbnail: CGImage?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: IbangaSpacing.m) {
            Group {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: AttachmentFormatting.symbolName(for: attachment.contentType))
                        .font(.title3)
                        .foregroundStyle(IbangaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(IbangaColors.accentSoft)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(.rect(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                Text(attachment.kind == .image ? String(localized: "Photo") : attachment.filename)
                    .font(IbangaTypography.callout.weight(.medium))
                    .foregroundStyle(IbangaColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: IbangaSpacing.xs) {
                    Image(systemName: IbangaIcons.lockFilled)
                        .accessibilityHidden(true)
                    Text("\(AttachmentFormatting.summary(contentType: attachment.contentType, byteCount: attachment.data.count)) · Encrypted when sent")
                }
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.textSecondary)
            }

            Spacer(minLength: IbangaSpacing.s)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(IbangaColors.textSecondary)
            }
            .accessibilityLabel("Remove attachment")
        }
        .padding(IbangaSpacing.s)
        .background(IbangaColors.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}
