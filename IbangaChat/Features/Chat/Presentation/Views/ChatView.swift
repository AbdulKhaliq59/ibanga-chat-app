import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var scrolledRowID: String?
    @State private var peerSecurity: PeerSecurityViewModel?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: IbangaSpacing.xxs) {
                if viewModel.hasLoaded && viewModel.messages.isEmpty {
                    emptyState
                }
                ForEach(viewModel.rows) { row in
                    rowView(row)
                        .transition(messageTransition)
                }
            }
            .padding(.horizontal, IbangaSpacing.m)
            .padding(.vertical, IbangaSpacing.s)
            .scrollTargetLayout()
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.15), value: viewModel.messages.map(\.id))
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition(id: $scrolledRowID, anchor: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .background(IbangaColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.connectionState != .secure || viewModel.notice != nil {
                    connectionBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                MessageComposer(text: $viewModel.draft, canSend: viewModel.canSend) {
                    Task { await viewModel.send() }
                }
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.connectionState)
            .animation(.easeOut(duration: 0.2), value: viewModel.notice)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    peerSecurity = viewModel.makePeerSecurityViewModel()
                } label: {
                    VStack(spacing: 1) {
                        Text(viewModel.peer?.displayName ?? "")
                            .font(IbangaTypography.headline)
                            .foregroundStyle(IbangaColors.textPrimary)
                        ConnectionStatusView(state: viewModel.connectionState)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows security details and verification code")
            }
        }
        .sheet(item: $peerSecurity) { viewModel in
            PeerSecurityView(viewModel: viewModel)
        }
        .onChange(of: viewModel.messages.last?.id) { _, newValue in
            guard let newValue else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                scrolledRowID = newValue.uuidString
            }
        }
        .task { await viewModel.load() }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.messages.count)
    }

    @ViewBuilder
    private func rowView(_ row: ChatViewModel.Row) -> some View {
        switch row.kind {
        case .day(let date):
            Text(Self.dayTitle(for: date))
                .font(IbangaTypography.caption.weight(.medium))
                .foregroundStyle(IbangaColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, IbangaSpacing.m)
                .accessibilityAddTraits(.isHeader)
        case let .message(message, isFirst, isLast):
            MessageBubble(message: message, isFirstInGroup: isFirst, isLastInGroup: isLast)
        }
    }

    private var emptyState: some View {
        VStack(spacing: IbangaSpacing.m) {
            Image(systemName: IbangaIcons.lockFilled)
                .font(.title2)
                .foregroundStyle(IbangaColors.accent)
                .accessibilityHidden(true)
            Text("Your conversation is private.")
                .font(IbangaTypography.headline)
                .foregroundStyle(IbangaColors.textPrimary)
            Text("Send a message to begin.")
                .font(IbangaTypography.callout)
                .foregroundStyle(IbangaColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private var connectionBanner: some View {
        HStack(spacing: IbangaSpacing.m) {
            if viewModel.connectionState.isInProgress || viewModel.isReconnecting {
                ProgressView()
                Text(viewModel.connectionState == .connecting ? "Connecting…" : "Establishing secure session…")
                    .font(IbangaTypography.footnote)
                    .foregroundStyle(IbangaColors.textSecondary)
                Spacer(minLength: 0)
            } else {
                Image(systemName: viewModel.connectionState == .secure ? IbangaIcons.warning : IbangaIcons.notConnected)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .accessibilityHidden(true)
                Text(viewModel.notice ?? "Not connected. Messages are only sent over a secure connection.")
                    .font(IbangaTypography.footnote)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if viewModel.connectionState != .secure {
                    Button("Reconnect") {
                        Task { await viewModel.reconnect() }
                    }
                    .font(IbangaTypography.footnote.weight(.semibold))
                    .tint(IbangaColors.accent)
                }
            }
        }
        .padding(.horizontal, IbangaSpacing.l)
        .padding(.vertical, IbangaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IbangaColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(IbangaColors.separator).frame(height: 0.5)
        }
    }

    private var messageTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private static func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

extension PeerSecurityViewModel: Identifiable {
    var id: Peer.ID { peerID }
}
