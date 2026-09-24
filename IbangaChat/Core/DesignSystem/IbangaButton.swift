import SwiftUI

struct IbangaButton: View {
    enum Style {
        case primary
        case secondary
    }

    private let title: LocalizedStringKey
    private let style: Style
    private let isLoading: Bool
    private let action: () -> Void

    init(_ title: LocalizedStringKey, style: Style = .primary, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                }
            }
        }
        .buttonStyle(IbangaButtonStyle(foreground: foreground, background: background))
        .disabled(isLoading)
        .accessibilityValue(isLoading ? Text("In progress") : Text(""))
    }

    private var foreground: Color {
        style == .primary ? IbangaColors.onAccent : IbangaColors.accent
    }

    private var background: Color {
        style == .primary ? IbangaColors.accent : IbangaColors.accentSoft
    }
}

private struct IbangaButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IbangaTypography.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, IbangaSpacing.l)
            .background(background, in: .rect(cornerRadius: IbangaRadius.control, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(.rect)
    }
}

#Preview {
    VStack(spacing: IbangaSpacing.m) {
        IbangaButton("Continue") {}
        IbangaButton("Creating", isLoading: true) {}
        IbangaButton("Run again", style: .secondary) {}
    }
    .padding()
}
