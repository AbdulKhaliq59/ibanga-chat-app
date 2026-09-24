import SwiftUI

struct ImageViewer: View {
    let attachment: Attachment
    let loadImage: (Attachment) async -> CGImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification.simultaneously(with: pan))
                    .onTapGesture(count: 2, perform: toggleZoom)
                    .accessibilityLabel("Photo")
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .top) { toolbar }
        .task { image = await loadImage(attachment) }
        .statusBarHidden()
    }

    private var toolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .accessibilityLabel("Close")

            Spacer()

            if let image {
                ShareLink(
                    item: Image(decorative: image, scale: 1),
                    preview: SharePreview("Photo", image: Image(decorative: image, scale: 1))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Share")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, IbangaSpacing.l)
        .padding(.top, IbangaSpacing.s)
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(committedScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                committedScale = scale
                if scale == 1 { resetPosition() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                if scale > 1 {
                    committedOffset = offset
                } else if value.translation.height > 120 {
                    dismiss()
                }
            }
    }

    private func toggleZoom() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            if scale > 1 {
                scale = 1
                committedScale = 1
                resetPosition()
            } else {
                scale = 2.5
                committedScale = 2.5
            }
        }
    }

    private func resetPosition() {
        offset = .zero
        committedOffset = .zero
    }
}
