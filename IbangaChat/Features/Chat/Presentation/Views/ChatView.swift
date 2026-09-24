import PhotosUI
import QuickLook
import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var scrolledRowID: String?
    @State private var peerSecurity: PeerSecurityViewModel?
    @State private var viewedPhoto: Attachment?

    @State private var isShowingAttachmentOptions = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var isShowingCamera = false
    @State private var photoSelection: PhotosPickerItem?

    @State private var showsSecureConfirmation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let incomingTransferRowID = "incoming-transfer"

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        messageList
            .background(IbangaColors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { header }
            }
            .sheet(item: $peerSecurity) { viewModel in
                PeerSecurityView(viewModel: viewModel)
            }
            .confirmationDialog("Add Attachment", isPresented: $isShowingAttachmentOptions, titleVisibility: .visible) {
                Button("Photos") { isShowingPhotoPicker = true }
                Button("Files") { isShowingFileImporter = true }
                if CameraPicker.isAvailable {
                    Button("Camera") { isShowingCamera = true }
                }
            } message: {
                Text("Attachments are encrypted automatically before they leave this device.")
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoSelection, matching: .images)
            .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.item]) { result in
                guard case .success(let url) = result else { return }
                Task { await viewModel.attach(fileAt: url) }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    Task { await viewModel.attach(imageData: data) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $viewedPhoto) { attachment in
                ImageViewer(attachment: attachment) { await viewModel.fullImage(for: $0) }
            }
            .quickLookPreview($viewModel.previewURL)
            .onChange(of: viewModel.previewURL) { oldValue, newValue in
                if oldValue != nil, newValue == nil { viewModel.previewDismissed() }
            }
            .onChange(of: photoSelection) { _, item in
                guard let item else { return }
                photoSelection = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.attach(imageData: data)
                    }
                }
            }
            .onChange(of: viewModel.connectionState) { oldValue, newValue in
                guard oldValue != .secure, newValue == .secure else { return }
                showsSecureConfirmation = true
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    showsSecureConfirmation = false
                }
            }
            .onChange(of: viewModel.messages.last?.id) { _, newValue in
                guard let newValue else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    scrolledRowID = newValue.uuidString
                }
            }
            .onChange(of: viewModel.incomingTransferProgress != nil) { _, isReceiving in
                guard isReceiving else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    scrolledRowID = Self.incomingTransferRowID
                }
            }
            .task { await viewModel.load() }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.messages.count)
            .sensoryFeedback(.success, trigger: showsSecureConfirmation) { _, isShowing in isShowing }
    }

    // MARK: Sections

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: IbangaSpacing.xxs) {
                if viewModel.hasLoaded && viewModel.messages.isEmpty {
                    emptyState
                }
                ForEach(viewModel.rows) { row in
                    rowView(row)
                        .transition(messageTransition)
                }
                if let progress = viewModel.incomingTransferProgress {
                    IncomingTransferBubble(progress: progress)
                        .id(Self.incomingTransferRowID)
                        .transition(.opacity)
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
    }

    private var header: some View {
        Button {
            peerSecurity = viewModel.makePeerSecurityViewModel()
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: IbangaSpacing.xs) {
                    Text(viewModel.peer?.displayName ?? "")
                        .font(IbangaTypography.headline)
                        .foregroundStyle(IbangaColors.textPrimary)
                    if viewModel.peer?.isVerified == true {
                        Image(systemName: IbangaIcons.verified)
                            .font(.caption)
                            .foregroundStyle(IbangaColors.accent)
                            .accessibilityLabel("Verified")
                    }
                }
                ConnectionStatusView(state: viewModel.connectionState)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows security details and verification code")
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if let banner {
                ConnectionBanner(
                    content: banner,
                    isReconnecting: viewModel.isReconnecting,
                    onReconnect: { Task { await viewModel.reconnect() } },
                    onDismiss: viewModel.dismissNotice
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            MessageComposer(
                text: $viewModel.draft,
                canSend: viewModel.canSend,
                pendingAttachment: viewModel.pendingAttachment,
                pendingThumbnail: viewModel.pendingThumbnail,
                isPreparingAttachment: viewModel.isPreparingAttachment,
                onAddAttachment: { isShowingAttachmentOptions = true },
                onRemoveAttachment: viewModel.removePendingAttachment,
                onSend: { Task { await viewModel.send() } }
            )
        }
        .animation(.easeOut(duration: 0.25), value: banner)
    }

    /// Connecting… → Establishing secure session… → Secure connection established, or a clear failure.
    private var banner: ConnectionBanner.Content? {
        if let notice = viewModel.notice {
            return .notice(notice)
        }
        switch viewModel.connectionState {
        case .connecting, .establishingSession:
            return .inProgress(viewModel.connectionState)
        case .failed:
            return .failed
        case .inactive:
            return viewModel.isReconnecting ? .inProgress(.connecting) : .disconnected
        case .secure:
            return showsSecureConfirmation ? .established : nil
        }
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
            MessageBubble(
                message: message,
                isFirstInGroup: isFirst,
                isLastInGroup: isLast,
                transferProgress: viewModel.transferProgress(for: message),
                loadThumbnail: { await viewModel.thumbnail(for: $0) },
                onOpenAttachment: { attachment in
                    if attachment.kind == .image {
                        viewedPhoto = attachment
                    } else {
                        Task { await viewModel.open(attachment) }
                    }
                },
                onRetry: { Task { await viewModel.retry(message) } }
            )
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

private struct ConnectionBanner: View {
    enum Content: Equatable {
        case inProgress(SecureConnectionState)
        case established
        case disconnected
        case failed
        case notice(String)
    }

    let content: Content
    let isReconnecting: Bool
    let onReconnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: IbangaSpacing.m) {
            leadingIcon
            message
                .font(IbangaTypography.footnote)
                .foregroundStyle(content == .established ? IbangaColors.secure : IbangaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            trailingAction
        }
        .padding(.horizontal, IbangaSpacing.l)
        .padding(.vertical, IbangaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IbangaColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(IbangaColors.separator).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch content {
        case .inProgress:
            ProgressView()
        case .established:
            Image(systemName: IbangaIcons.lockFilled)
                .foregroundStyle(IbangaColors.secure)
                .transition(.scale.combined(with: .opacity))
        case .disconnected, .failed:
            Image(systemName: IbangaIcons.notConnected)
                .foregroundStyle(content == .failed ? IbangaColors.danger : IbangaColors.textSecondary)
        case .notice:
            Image(systemName: IbangaIcons.warning)
                .foregroundStyle(IbangaColors.warning)
        }
    }

    private var message: Text {
        switch content {
        case .inProgress(let state): Text(state.title)
        case .established: Text("Secure connection established")
        case .disconnected: Text("Not connected. Messages are only sent over a secure connection.")
        case .failed: Text("Unable to establish a secure connection.")
        case .notice(let notice): Text(notice)
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        switch content {
        case .disconnected:
            Button("Reconnect", action: onReconnect)
                .font(IbangaTypography.footnote.weight(.semibold))
                .tint(IbangaColors.accent)
                .disabled(isReconnecting)
        case .failed:
            Button("Try Again", action: onReconnect)
                .font(IbangaTypography.footnote.weight(.semibold))
                .tint(IbangaColors.accent)
                .disabled(isReconnecting)
        case .notice:
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IbangaColors.textTertiary)
            }
            .accessibilityLabel("Dismiss")
        case .inProgress, .established:
            EmptyView()
        }
    }
}

extension PeerSecurityViewModel: Identifiable {
    var id: Peer.ID { peerID }
}
