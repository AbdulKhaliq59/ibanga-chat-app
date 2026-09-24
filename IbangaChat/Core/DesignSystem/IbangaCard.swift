import SwiftUI

struct IbangaCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = IbangaSpacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IbangaColors.surface, in: .rect(cornerRadius: IbangaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IbangaRadius.card, style: .continuous)
                    .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
            }
    }
}

struct IbangaSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let footer: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.s) {
            Text(title)
                .font(IbangaTypography.sectionHeader)
                .foregroundStyle(IbangaColors.textSecondary)
                .padding(.horizontal, IbangaSpacing.xs)
                .accessibilityAddTraits(.isHeader)

            IbangaCard(padding: 0) {
                content
            }

            if let footer {
                Text(footer)
                    .font(IbangaTypography.footnote)
                    .foregroundStyle(IbangaColors.textTertiary)
                    .padding(.horizontal, IbangaSpacing.xs)
            }
        }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}
