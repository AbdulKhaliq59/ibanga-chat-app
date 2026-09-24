import SwiftUI

struct PairingView: View {
    @State private var viewModel: PairingViewModel
    @State private var isRenaming = false
    @State private var nameDraft = ""
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PairingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                identitySection
                devicesSection
            }
            .scrollContentBackground(.hidden)
            .background(IbangaColors.background.ignoresSafeArea())
            .navigationTitle("Connect Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Your name", isPresented: $isRenaming) {
                TextField("Name", text: $nameDraft)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    Task { await viewModel.rename(to: nameDraft) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is how you appear to nearby devices.")
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.devices)
        }
    }

    private var identitySection: some View {
        Section {
            HStack(spacing: IbangaSpacing.m) {
                PeerAvatar(name: viewModel.displayName, size: 40)
                VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                    Text("Visible as")
                        .font(IbangaTypography.caption)
                        .foregroundStyle(IbangaColors.textSecondary)
                    Text(viewModel.displayName)
                        .font(IbangaTypography.headline)
                        .foregroundStyle(IbangaColors.textPrimary)
                }
                Spacer()
                Button("Edit") {
                    nameDraft = viewModel.displayName
                    isRenaming = true
                }
                .font(IbangaTypography.callout.weight(.medium))
                .tint(IbangaColors.accent)
            }
            .padding(.vertical, IbangaSpacing.xs)
            .listRowBackground(IbangaColors.surface)
        } footer: {
            Text("Nearby devices running Ibanga can see this name.")
        }
    }

    private var devicesSection: some View {
        Section {
            if viewModel.devices.isEmpty {
                HStack(spacing: IbangaSpacing.m) {
                    ProgressView()
                    Text("Looking for nearby devices…")
                        .font(IbangaTypography.callout)
                        .foregroundStyle(IbangaColors.textSecondary)
                }
                .padding(.vertical, IbangaSpacing.s)
                .listRowBackground(IbangaColors.surface)
            } else {
                ForEach(viewModel.devices) { device in
                    DeviceRow(device: device, status: viewModel.status(for: device)) {
                        Task { await viewModel.connect(to: device) }
                    }
                    .listRowBackground(IbangaColors.surface)
                }
            }
        } header: {
            Text("Nearby")
        } footer: {
            Text("Both devices need Ibanga open on the same Wi‑Fi network. A secure session is established automatically.")
        }
    }
}

private struct DeviceRow: View {
    let device: NearbyDevice
    let status: PairingViewModel.DeviceStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: IbangaSpacing.m) {
                PeerAvatar(name: device.name, size: 40)

                VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                    Text(device.name)
                        .font(IbangaTypography.body)
                        .foregroundStyle(IbangaColors.textPrimary)
                    statusLine
                }

                Spacer(minLength: IbangaSpacing.s)
                trailing
            }
            .padding(.vertical, IbangaSpacing.xs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
        .animation(.easeOut(duration: 0.2), value: status)
        .accessibilityHint("Connects securely to this device")
    }

    private var isConnecting: Bool {
        if case .connecting = status { return true }
        return false
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .connecting(let state):
            Text(state.title)
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.textSecondary)
        case .connected:
            Text("Secure connection established")
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.secure)
        case .failed(let message):
            Text(message)
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.danger)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .connecting:
            ProgressView()
        case .connected:
            Image(systemName: IbangaIcons.checkmarkCircle)
                .foregroundStyle(IbangaColors.secure)
                .transition(.scale.combined(with: .opacity))
        case .idle, .failed:
            Image(systemName: IbangaIcons.chevronRight)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(IbangaColors.textTertiary)
        }
    }
}
