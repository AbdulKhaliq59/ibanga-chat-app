import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepIndicator(current: viewModel.step == .welcome ? 0 : 1, total: 2)
                .padding(.top, IbangaSpacing.l)

            ZStack(alignment: .topLeading) {
                switch viewModel.step {
                case .welcome:
                    WelcomeStep()
                        .transition(stepTransition)
                case .identity:
                    IdentityStep(state: viewModel.identityState)
                        .transition(stepTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(.horizontal, IbangaSpacing.screenMargin)
        .padding(.bottom, IbangaSpacing.l)
        .background(IbangaColors.background.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: viewModel.identityState == .created)
    }

    @ViewBuilder
    private var footer: some View {
        switch viewModel.step {
        case .welcome:
            IbangaButton("Continue") {
                withAnimation(stepAnimation) { viewModel.continueToIdentity() }
            }
        case .identity:
            VStack(spacing: IbangaSpacing.m) {
                if case .failed(let error) = viewModel.identityState {
                    Text(error.message)
                        .font(IbangaTypography.footnote)
                        .foregroundStyle(IbangaColors.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
                IbangaButton(
                    viewModel.identityState == .created ? "Identity Created" : "Create Secure Identity",
                    isLoading: viewModel.identityState == .creating
                ) {
                    Task { await viewModel.createSecureIdentity() }
                }
                .disabled(viewModel.identityState == .created)
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.identityState)
        }
    }

    private var stepAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.1)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.xl) {
            Spacer(minLength: IbangaSpacing.xxxl)

            BrandMark()

            VStack(alignment: .leading, spacing: IbangaSpacing.m) {
                Text("Ibanga")
                    .font(IbangaTypography.wordmark)
                    .foregroundStyle(IbangaColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Private communication,\ndesigned differently.")
                    .font(IbangaTypography.title)
                    .foregroundStyle(IbangaColors.textPrimary)

                Text("Your conversations are protected by modern cryptography.")
                    .font(IbangaTypography.body)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

private struct IdentityStep: View {
    let state: OnboardingViewModel.IdentityState

    var body: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.xl) {
            Spacer(minLength: IbangaSpacing.xxxl)

            ZStack {
                Circle()
                    .fill(IbangaColors.accentSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: state == .created ? IbangaIcons.checkmark : IbangaIcons.keyFilled)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(IbangaColors.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: IbangaSpacing.m) {
                Text("Secure by design")
                    .font(IbangaTypography.display)
                    .foregroundStyle(IbangaColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Your identity keys are generated and stored securely on this device.")
                    .font(IbangaTypography.body)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: IbangaSpacing.m) {
                Assurance(icon: IbangaIcons.iPhone, text: "Created on this iPhone")
                Assurance(icon: IbangaIcons.lock, text: "Kept in the iOS Keychain")
                Assurance(icon: IbangaIcons.shield, text: "Never leaves your device")
            }
            .padding(.top, IbangaSpacing.s)

            Spacer()
        }
    }
}

private struct Assurance: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
                .font(IbangaTypography.callout)
                .foregroundStyle(IbangaColors.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(IbangaColors.accent)
                .frame(width: 24)
        }
    }
}

private struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: IbangaSpacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? IbangaColors.accent : IbangaColors.separator)
                    .frame(width: index == current ? 24 : 8, height: 4)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(
        createIdentity: CreateIdentityUseCase(repository: PreviewIdentityRepository()),
        onComplete: { _ in }
    ))
}
