import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(IbangaColors.accent)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: IbangaIcons.lockFilled)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(IbangaColors.onAccent)
            }
            .accessibilityHidden(true)
    }
}
