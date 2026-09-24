import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @FocusState private var isEditingName: Bool

    private let securityDestination: () -> AnyView

    init(viewModel: SettingsViewModel, securityDestination: @escaping () -> AnyView) {
        _viewModel = State(initialValue: viewModel)
        self.securityDestination = securityDestination
    }

    var body: some View {
        List {
            profileHeader
            nameSection
            appearanceSection
            securitySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(IbangaColors.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: viewModel.savedNameCount)
    }

    // MARK: Sections

    private var profileHeader: some View {
        Section {
            VStack(spacing: IbangaSpacing.m) {
                PeerAvatar(name: viewModel.displayName, size: 76)
                VStack(spacing: IbangaSpacing.xxs) {
                    Text(viewModel.displayName)
                        .font(IbangaTypography.title)
                        .foregroundStyle(IbangaColors.textPrimary)
                        .contentTransition(.opacity)
                    Label("Secure identity active", systemImage: IbangaIcons.lockFilled)
                        .font(IbangaTypography.caption)
                        .foregroundStyle(IbangaColors.secure)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, IbangaSpacing.s)
            .listRowBackground(Color.clear)
            .animation(.easeOut(duration: 0.2), value: viewModel.displayName)
        }
    }

    private var nameSection: some View {
        Section {
            HStack(spacing: IbangaSpacing.m) {
                SettingsIcon(systemName: "person.fill", tint: IbangaColors.accent)
                TextField("Your name", text: $viewModel.nameDraft)
                    .focused($isEditingName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { Task { await viewModel.saveName() } }
                    .onChange(of: viewModel.nameDraft) { _, newValue in
                        if newValue.count > viewModel.maximumNameLength {
                            viewModel.nameDraft = String(newValue.prefix(viewModel.maximumNameLength))
                        }
                    }
                if viewModel.canSaveName {
                    Button("Save") {
                        isEditingName = false
                        Task { await viewModel.saveName() }
                    }
                    .font(IbangaTypography.callout.weight(.semibold))
                    .tint(IbangaColors.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: viewModel.canSaveName)
            .listRowBackground(IbangaColors.surface)
        } header: {
            Text("Display name")
        } footer: {
            if let error = viewModel.nameError {
                Text(error).foregroundStyle(IbangaColors.danger)
            } else {
                Text("Nearby devices running Ibanga see this name. Your identity is verified by cryptographic keys, not by name.")
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            HStack(spacing: IbangaSpacing.m) {
                ForEach(AppearancePreference.allCases) { preference in
                    AppearanceOption(
                        preference: preference,
                        isSelected: viewModel.appearance == preference
                    ) {
                        viewModel.setAppearance(preference)
                    }
                }
            }
            .padding(.vertical, IbangaSpacing.s)
            .listRowBackground(IbangaColors.surface)
            .sensoryFeedback(.selection, trigger: viewModel.appearance)
        } header: {
            Text("Appearance")
        }
    }

    private var securitySection: some View {
        Section {
            NavigationLink {
                securityDestination()
            } label: {
                HStack(spacing: IbangaSpacing.m) {
                    SettingsIcon(systemName: IbangaIcons.shieldFilled, tint: IbangaColors.accent)
                    VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                        Text("Security & Privacy")
                            .foregroundStyle(IbangaColors.textPrimary)
                        Text("Identity \(viewModel.shortFingerprint)")
                            .font(IbangaTypography.caption.monospaced())
                            .foregroundStyle(IbangaColors.textSecondary)
                    }
                }
            }
            .listRowBackground(IbangaColors.surface)
        } header: {
            Text("Security")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: viewModel.appVersion)
                .listRowBackground(IbangaColors.surface)
            LabeledContent("Encryption", value: "End-to-end")
                .listRowBackground(IbangaColors.surface)
        } header: {
            Text("About")
        } footer: {
            VStack(spacing: IbangaSpacing.s) {
                BrandMark(size: 36)
                Text("Ibanga — private communication, designed with security at the core.")
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, IbangaSpacing.xl)
        }
    }
}

private struct AppearanceOption: View {
    let preference: AppearancePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: IbangaSpacing.s) {
                preview
                    .frame(height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? IbangaColors.accent : IbangaColors.separator, lineWidth: isSelected ? 2 : 0.5)
                    }
                Label(preference.title, systemImage: preference.symbolName)
                    .labelStyle(.titleOnly)
                    .font(IbangaTypography.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? IbangaColors.accent : IbangaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(preference.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var preview: some View {
        switch preference {
        case .light:
            MiniChatPreview(background: Color(white: 0.97), bubble: Color(white: 0.86), accent: Color(red: 0.12, green: 0.36, blue: 0.31))
        case .dark:
            MiniChatPreview(background: Color(white: 0.07), bubble: Color(white: 0.2), accent: Color(red: 0.42, green: 0.8, blue: 0.69))
        case .system:
            HStack(spacing: 0) {
                MiniChatPreview(background: Color(white: 0.97), bubble: Color(white: 0.86), accent: Color(red: 0.12, green: 0.36, blue: 0.31), corners: .leading)
                MiniChatPreview(background: Color(white: 0.07), bubble: Color(white: 0.2), accent: Color(red: 0.42, green: 0.8, blue: 0.69), corners: .trailing)
            }
        }
    }
}

private struct MiniChatPreview: View {
    enum Corners { case all, leading, trailing }

    let background: Color
    let bubble: Color
    let accent: Color
    var corners: Corners = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(bubble).frame(width: 26, height: 8)
            Capsule().fill(accent).frame(width: 22, height: 8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Capsule().fill(bubble).frame(width: 18, height: 8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = 12
        return UnevenRoundedRectangle(
            topLeadingRadius: corners == .trailing ? 0 : radius,
            bottomLeadingRadius: corners == .trailing ? 0 : radius,
            bottomTrailingRadius: corners == .leading ? 0 : radius,
            topTrailingRadius: corners == .leading ? 0 : radius,
            style: .continuous
        )
    }
}

private struct SettingsIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(IbangaColors.onAccent)
            .frame(width: 30, height: 30)
            .background(tint, in: .rect(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}
