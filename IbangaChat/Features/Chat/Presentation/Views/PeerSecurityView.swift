import SwiftUI

struct PeerSecurityView: View {
    @State private var viewModel: PeerSecurityViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PeerSecurityViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: IbangaSpacing.xl) {
                    header
                    verificationSection
                    protectionSection
                    if viewModel.connectionState == .secure {
                        Button("Disconnect", role: .destructive) {
                            Task { await viewModel.disconnect() }
                        }
                        .font(IbangaTypography.callout)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, IbangaSpacing.screenMargin)
                .padding(.bottom, IbangaSpacing.xxl)
            }
            .background(IbangaColors.background.ignoresSafeArea())
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .sensoryFeedback(.success, trigger: viewModel.isVerified) { _, isVerified in isVerified }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: IbangaSpacing.m) {
            PeerAvatar(name: viewModel.peer?.displayName ?? "", size: 64)
            HStack(spacing: IbangaSpacing.xs) {
                Text(viewModel.peer?.displayName ?? "")
                    .font(IbangaTypography.title)
                    .foregroundStyle(IbangaColors.textPrimary)
                if viewModel.isVerified {
                    Image(systemName: IbangaIcons.verified)
                        .foregroundStyle(IbangaColors.accent)
                        .accessibilityLabel("Verified")
                }
            }
            ConnectionStatusView(state: viewModel.connectionState)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, IbangaSpacing.l)
    }

    private var verificationSection: some View {
        IbangaSection(
            "Verification code",
            footer: "Compare this code with the one shown on the other device. If they match, no one is intercepting your conversation."
        ) {
            VStack(spacing: IbangaSpacing.l) {
                Group {
                    if let code = viewModel.verificationCode {
                        Text(code)
                            .font(.system(.title, design: .monospaced).weight(.semibold))
                            .foregroundStyle(IbangaColors.textPrimary)
                            .accessibilityLabel(code.map { String($0) }.joined(separator: " "))
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)

                if viewModel.isVerified {
                    VStack(spacing: IbangaSpacing.s) {
                        Label("Verified", systemImage: IbangaIcons.verified)
                            .font(IbangaTypography.headline)
                            .foregroundStyle(IbangaColors.accent)
                        Button("Remove Verification", role: .destructive) {
                            viewModel.setVerified(false)
                        }
                        .font(IbangaTypography.footnote)
                    }
                } else {
                    IbangaButton("Mark as Verified") {
                        viewModel.setVerified(true)
                    }
                    .disabled(viewModel.verificationCode == nil)
                }
            }
            .padding(IbangaSpacing.l)
            .animation(.easeOut(duration: 0.2), value: viewModel.isVerified)
        }
    }

    private var protectionSection: some View {
        IbangaSection("Protection") {
            VStack(alignment: .leading, spacing: 0) {
                row("Encryption", "AES-GCM · 256-bit")
                Divider().padding(.leading, IbangaSpacing.l)
                row("Key agreement", "X25519 · per connection")
                Divider().padding(.leading, IbangaSpacing.l)
                VStack(alignment: .leading, spacing: IbangaSpacing.xs) {
                    Text("Identity fingerprint")
                        .font(IbangaTypography.callout)
                        .foregroundStyle(IbangaColors.textPrimary)
                    Text(viewModel.formattedFingerprint)
                        .font(IbangaTypography.monospaced)
                        .foregroundStyle(IbangaColors.textSecondary)
                        .textSelection(.enabled)
                }
                .padding(IbangaSpacing.l)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(IbangaColors.textPrimary)
            Spacer()
            Text(value).foregroundStyle(IbangaColors.textSecondary)
        }
        .font(IbangaTypography.callout)
        .padding(IbangaSpacing.l)
        .accessibilityElement(children: .combine)
    }
}
