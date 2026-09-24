import SwiftUI

struct AttachmentTray: View {
    enum Option: Identifiable, Hashable {
        case photos
        case camera
        case document

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .photos: "Photos"
            case .camera: "Camera"
            case .document: "Document"
            }
        }

        var symbolName: String {
            switch self {
            case .photos: "photo.on.rectangle.angled"
            case .camera: "camera.fill"
            case .document: "doc.fill"
            }
        }

        var tint: Color {
            switch self {
            case .photos: Color(red: 0.25, green: 0.49, blue: 0.93)
            case .camera: Color(red: 0.89, green: 0.33, blue: 0.47)
            case .document: Color(red: 0.49, green: 0.37, blue: 0.88)
            }
        }
    }

    let options: [Option]
    let onSelect: (Option) -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.l) {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: IbangaSpacing.s) {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(option.tint.gradient, in: .circle)
                                .shadow(color: option.tint.opacity(0.35), radius: 6, y: 3)
                            Text(option.title)
                                .font(IbangaTypography.caption)
                                .foregroundStyle(IbangaColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TrayButtonStyle())
                    .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.4)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.42, bounce: 0.4).delay(Double(index) * 0.045),
                        value: hasAppeared
                    )
                }
            }

            Label("Encrypted before it leaves your device", systemImage: IbangaIcons.lockFilled)
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, IbangaSpacing.xl)
        .padding(.horizontal, IbangaSpacing.m)
        .background(IbangaColors.surface, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(IbangaColors.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 24, y: 10)
        .padding(.horizontal, IbangaSpacing.m)
        .onAppear { hasAppeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add attachment")
    }
}

private struct TrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        Spacer()
        AttachmentTray(options: [.photos, .camera, .document]) { _ in }
    }
    .background(IbangaColors.background)
}
