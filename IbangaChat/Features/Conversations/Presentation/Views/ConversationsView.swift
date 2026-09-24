import SwiftUI

struct ConversationsView: View {
    let identity: DeviceIdentity
    let makeSecurityViewModel: () -> SecurityViewModel

    @State private var isShowingSecurity = false

    var body: some View {
        NavigationStack {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(IbangaColors.background.ignoresSafeArea())
                .navigationTitle("Ibanga")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingSecurity = true
                        } label: {
                            Image(systemName: IbangaIcons.shield)
                        }
                        .tint(IbangaColors.accent)
                        .accessibilityLabel("Security")
                    }
                }
                .navigationDestination(isPresented: $isShowingSecurity) {
                    SecurityView(viewModel: makeSecurityViewModel())
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: IbangaSpacing.xl) {
            Image(systemName: IbangaIcons.conversations)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(IbangaColors.textTertiary)
                .accessibilityHidden(true)

            VStack(spacing: IbangaSpacing.s) {
                Text("Private conversations,\nwithout the noise.")
                    .font(IbangaTypography.title)
                    .foregroundStyle(IbangaColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your conversations will appear here.")
                    .font(IbangaTypography.callout)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                isShowingSecurity = true
            } label: {
                HStack(spacing: IbangaSpacing.s) {
                    StatusDot(color: IbangaColors.secure)
                    Text("Secure identity active")
                        .font(IbangaTypography.footnote.weight(.medium))
                        .foregroundStyle(IbangaColors.textPrimary)
                }
                .padding(.horizontal, IbangaSpacing.m)
                .padding(.vertical, IbangaSpacing.s)
                .background(IbangaColors.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(IbangaColors.separator, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows security details")
        }
        .padding(.horizontal, IbangaSpacing.xxl)
    }
}

#Preview {
    ConversationsView(identity: PreviewIdentityRepository.identity) {
        SecurityViewModel(
            identity: PreviewIdentityRepository.identity,
            connectionState: .inactive,
            runSecurityCheck: RunSecurityCheckUseCase(service: PreviewSecurityService())
        )
    }
}
