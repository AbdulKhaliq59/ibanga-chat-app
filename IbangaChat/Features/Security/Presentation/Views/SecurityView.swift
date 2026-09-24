import SwiftUI

struct SecurityView: View {
    @State private var viewModel: SecurityViewModel
    @State private var showsCheckDetails = false

    init(viewModel: SecurityViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IbangaSpacing.xl) {
                header
                deviceSection
                protectionSection
                connectionSection
                integritySection
            }
            .padding(.horizontal, IbangaSpacing.screenMargin)
            .padding(.bottom, IbangaSpacing.xxl)
        }
        .background(IbangaColors.background.ignoresSafeArea())
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.runChecks() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: IbangaSpacing.m) {
            Image(systemName: IbangaIcons.shieldFilled)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(IbangaColors.accent)
                .accessibilityHidden(true)

            Text("Protected by design")
                .font(IbangaTypography.display)
                .foregroundStyle(IbangaColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Your identity is generated on this device and stored in the iOS Keychain. Messages are encrypted before they leave your iPhone.")
                .font(IbangaTypography.callout)
                .foregroundStyle(IbangaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, IbangaSpacing.l)
    }

    private var deviceSection: some View {
        IbangaSection("This device") {
            VStack(spacing: 0) {
                DetailRow(label: "Identity") {
                    HStack(spacing: IbangaSpacing.s) {
                        StatusDot(color: IbangaColors.secure)
                        Text("Active")
                    }
                }
                Divider().padding(.leading, IbangaSpacing.l)
                VStack(alignment: .leading, spacing: IbangaSpacing.xs) {
                    Text("Fingerprint")
                        .font(IbangaTypography.callout)
                        .foregroundStyle(IbangaColors.textPrimary)
                    Text(viewModel.formattedFingerprint)
                        .font(IbangaTypography.monospaced)
                        .foregroundStyle(IbangaColors.textSecondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(IbangaSpacing.l)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var protectionSection: some View {
        IbangaSection("Protection", footer: "Keys never leave this device and are not included in backups.") {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.mechanisms.enumerated()), id: \.element.id) { index, mechanism in
                    if index > 0 {
                        Divider().padding(.leading, IbangaSpacing.l)
                    }
                    DetailRow(label: LocalizedStringKey(mechanism.label)) {
                        Text(mechanism.value)
                    }
                }
            }
        }
    }

    private var connectionSection: some View {
        IbangaSection("Connection", footer: "A secure session is established automatically when you connect to another device.") {
            DetailRow(label: "Status") {
                HStack(spacing: IbangaSpacing.s) {
                    StatusDot(color: viewModel.hasSecureConnection ? IbangaColors.secure : IbangaColors.neutral)
                    Text(viewModel.connectionSummary)
                }
            }
        }
    }

    private var integritySection: some View {
        IbangaSection("Verification") {
            VStack(spacing: 0) {
                integritySummary
                if showsCheckDetails, case .completed(let report) = viewModel.integrity {
                    Divider().padding(.leading, IbangaSpacing.l)
                    VStack(alignment: .leading, spacing: IbangaSpacing.m) {
                        ForEach(report.checks) { check in
                            CheckRow(check: check)
                        }
                    }
                    .padding(IbangaSpacing.l)
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private var integritySummary: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { showsCheckDetails.toggle() }
        } label: {
            HStack(spacing: IbangaSpacing.m) {
                integrityIcon
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                    Text(integrityTitle)
                        .font(IbangaTypography.callout)
                        .foregroundStyle(IbangaColors.textPrimary)
                    Text(integritySubtitle)
                        .font(IbangaTypography.footnote)
                        .foregroundStyle(IbangaColors.textSecondary)
                }

                Spacer(minLength: IbangaSpacing.s)

                if case .completed = viewModel.integrity {
                    Image(systemName: IbangaIcons.chevronRight)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(IbangaColors.textTertiary)
                        .rotationEffect(.degrees(showsCheckDetails ? 90 : 0))
                        .accessibilityHidden(true)
                }
            }
            .padding(IbangaSpacing.l)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.integrity == .running)
        .accessibilityHint(showsCheckDetails ? "Hides individual checks" : "Shows individual checks")
    }

    @ViewBuilder
    private var integrityIcon: some View {
        switch viewModel.integrity {
        case .idle, .running:
            ProgressView()
        case .completed(let report):
            Image(systemName: report.allPassed ? IbangaIcons.checkmarkCircle : IbangaIcons.warning)
                .foregroundStyle(report.allPassed ? IbangaColors.secure : IbangaColors.warning)
                .font(.title3)
                .accessibilityHidden(true)
        }
    }

    private var integrityTitle: LocalizedStringKey {
        switch viewModel.integrity {
        case .idle, .running: "Verifying cryptography…"
        case .completed(let report): report.allPassed ? "Cryptography verified" : "Verification needs attention"
        }
    }

    private var integritySubtitle: LocalizedStringKey {
        switch viewModel.integrity {
        case .idle, .running: "Running on this device"
        case .completed(let report): "\(report.passedCount) of \(report.checks.count) checks passed"
        }
    }
}

private struct DetailRow<Value: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: IbangaSpacing.m) {
            Text(label)
                .foregroundStyle(IbangaColors.textPrimary)
            Spacer(minLength: IbangaSpacing.s)
            value
                .foregroundStyle(IbangaColors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .font(IbangaTypography.callout)
        .padding(IbangaSpacing.l)
        .accessibilityElement(children: .combine)
    }
}

private struct CheckRow: View {
    let check: SecurityCheck

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: IbangaSpacing.m) {
            Image(systemName: check.passed ? IbangaIcons.checkmark : IbangaIcons.failed)
                .font(.footnote.weight(.bold))
                .foregroundStyle(check.passed ? IbangaColors.secure : IbangaColors.danger)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(check.kind.title)
                .font(IbangaTypography.footnote)
                .foregroundStyle(IbangaColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(check.passed ? "Passed" : "Failed")
    }
}

#Preview {
    NavigationStack {
        SecurityView(viewModel: SecurityViewModel(
            identity: PreviewIdentityRepository.identity,
            sessions: PreviewSessionRepository(),
            runSecurityCheck: RunSecurityCheckUseCase(service: PreviewSecurityService())
        ))
    }
}
