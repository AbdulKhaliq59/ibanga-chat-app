import SwiftUI

struct PeerAvatar: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(IbangaColors.accentSoft)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(IbangaColors.accent)
            }
            .accessibilityHidden(true)
    }

    private var initials: String {
        let letters = name
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap(\.first)
            .filter(\.isLetter)
            .prefix(2)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
