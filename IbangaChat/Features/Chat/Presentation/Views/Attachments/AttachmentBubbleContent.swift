import SwiftUI

struct ImageAttachmentView: View {
    let attachment: Attachment
    let progress: Double?
    let loadImage: (Attachment) async -> CGImage?

    @State private var image: CGImage?
    @State private var didFail = false

    private let maximumSide: CGFloat = 240

    var body: some View {
        content
            .overlay {
                if let progress {
                    TransferProgressOverlay(progress: progress)
                }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
            }
            .task(id: attachment.id) {
                image = await loadImage(attachment)
                didFail = image == nil
            }
            .accessibilityElement()
            .accessibilityLabel("Photo")
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            let size = displaySize(for: image)
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(IbangaColors.surface)
                .frame(width: maximumSide, height: maximumSide * 0.75)
                .overlay {
                    if didFail {
                        Label("Image unavailable", systemImage: IbangaIcons.warning)
                            .font(IbangaTypography.caption)
                            .foregroundStyle(IbangaColors.textSecondary)
                    } else {
                        ProgressView()
                    }
                }
        }
    }

    private func displaySize(for image: CGImage) -> CGSize {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = maximumSide / max(width, height)
        return CGSize(width: max(120, width * scale), height: max(90, height * scale))
    }
}

struct FileAttachmentView: View {
    let attachment: Attachment
    let isOutgoing: Bool
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.s) {
            HStack(spacing: IbangaSpacing.m) {
                Image(systemName: AttachmentFormatting.symbolName(for: attachment.contentType))
                    .font(.title3)
                    .foregroundStyle(isOutgoing ? IbangaColors.onAccent : IbangaColors.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        (isOutgoing ? IbangaColors.onAccent.opacity(0.15) : IbangaColors.accentSoft),
                        in: .rect(cornerRadius: 10, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                    Text(attachment.filename)
                        .font(IbangaTypography.callout.weight(.medium))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text(AttachmentFormatting.summary(contentType: attachment.contentType, byteCount: attachment.byteCount))
                        .font(IbangaTypography.caption)
                        .opacity(0.75)
                }
                .foregroundStyle(isOutgoing ? IbangaColors.onAccent : IbangaColors.textPrimary)
            }

            if let progress {
                ProgressView(value: progress)
                    .tint(isOutgoing ? IbangaColors.onAccent : IbangaColors.accent)
            }
        }
        .padding(IbangaSpacing.m)
        .frame(maxWidth: 260, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct IncomingTransferBubble: View {
    let progress: Double

    var body: some View {
        HStack {
            HStack(spacing: IbangaSpacing.m) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(IbangaColors.accent)
                VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                    Text("Receiving attachment…")
                        .font(IbangaTypography.callout)
                        .foregroundStyle(IbangaColors.textPrimary)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(IbangaTypography.caption.monospacedDigit())
                        .foregroundStyle(IbangaColors.textSecondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(IbangaColors.surface, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
            }
            Spacer(minLength: IbangaSpacing.xxxl)
        }
        .padding(.top, IbangaSpacing.s)
        .animation(.easeOut(duration: 0.2), value: progress)
        .accessibilityElement(children: .combine)
    }
}

private struct TransferProgressOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: IbangaIcons.lockFilled)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .animation(.easeOut(duration: 0.2), value: progress)
        }
        .accessibilityElement()
        .accessibilityLabel("Sending encrypted photo")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
