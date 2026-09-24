import SwiftUI

struct RootView: View {
    let container: AppContainer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let appState = container.appState

        ZStack {
            switch appState.phase {
            case .launching:
                LaunchView()
            case .onboarding:
                OnboardingView(viewModel: container.makeOnboardingViewModel())
                    .transition(.opacity)
            case .ready(let identity):
                container.makeConversationsView(identity: identity)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                    .task(id: identity.fingerprint) {
                        await container.startMessaging(with: identity)
                    }
            case .failed(let error):
                StartupFailureView(error: error) {
                    Task { await appState.bootstrap() }
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.phase)
        .onAppear { container.appearance.apply() }
        .task { await appState.bootstrap() }
    }
}

private struct LaunchView: View {
    var body: some View {
        BrandMark(size: 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IbangaColors.background.ignoresSafeArea())
    }
}

struct StartupFailureView: View {
    let error: UserFacingError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: IbangaSpacing.xl) {
            Spacer()

            Image(systemName: IbangaIcons.shield)
                .font(.system(size: 40))
                .foregroundStyle(IbangaColors.textTertiary)
                .accessibilityHidden(true)

            VStack(spacing: IbangaSpacing.s) {
                Text(error.title)
                    .font(IbangaTypography.title)
                    .foregroundStyle(IbangaColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(error.message)
                    .font(IbangaTypography.callout)
                    .foregroundStyle(IbangaColors.textSecondary)
            }
            .multilineTextAlignment(.center)

            Spacer()

            if let retry {
                IbangaButton("Try Again", action: retry)
            }
        }
        .padding(.horizontal, IbangaSpacing.screenMargin)
        .padding(.bottom, IbangaSpacing.l)
        .background(IbangaColors.background.ignoresSafeArea())
    }
}
