import SwiftUI

/// Screens owned by other features, supplied by the composition root.
struct ConversationsDestinations {
    let chat: (Conversation.ID) -> AnyView
    let settings: () -> AnyView
    let pairing: (_ onConnected: @escaping (Conversation.ID) -> Void) -> AnyView
}

struct ConversationsView: View {
    private enum Route: Hashable {
        case chat(Conversation.ID)
        case settings
    }

    @State private var viewModel: ConversationsViewModel
    @State private var path: [Route] = []
    @State private var isShowingPairing = false

    private let destinations: ConversationsDestinations

    init(viewModel: ConversationsViewModel, destinations: ConversationsDestinations) {
        _viewModel = State(initialValue: viewModel)
        self.destinations = destinations
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IbangaColors.background.ignoresSafeArea())
            .navigationTitle("Ibanga")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(IbangaColors.accent)
                    .accessibilityLabel("Settings")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.conversations.isEmpty && !viewModel.isSearching {
                    newConversationButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.isSearching)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .chat(let id): destinations.chat(id)
                case .settings: destinations.settings()
                }
            }
            .sheet(isPresented: $isShowingPairing) {
                destinations.pairing { conversationID in
                    isShowingPairing = false
                    path = [.chat(conversationID)]
                }
            }
        }
    }

    // MARK: List

    private var conversationList: some View {
        List {
            if viewModel.isSearching {
                searchResults
            } else {
                ForEach(viewModel.conversations) { conversation in
                    conversationRow(conversation)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $viewModel.searchText, prompt: "Search chats and messages")
        .task(id: viewModel.query) { await viewModel.search() }
        .overlay {
            if viewModel.isSearching && viewModel.matchingConversations.isEmpty && viewModel.messageResults.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.conversations.map(\.id))
    }

    @ViewBuilder
    private var searchResults: some View {
        if !viewModel.matchingConversations.isEmpty {
            Section {
                ForEach(viewModel.matchingConversations) { conversation in
                    conversationRow(conversation)
                }
            } header: {
                sectionHeader("Chats")
            }
        }
        if !viewModel.messageResults.isEmpty {
            Section {
                ForEach(viewModel.messageResults) { message in
                    if let conversation = viewModel.conversation(for: message) {
                        Button {
                            path.append(.chat(conversation.id))
                        } label: {
                            MessageSearchRow(message: message, conversation: conversation, query: viewModel.query)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(IbangaColors.background)
                        .listRowInsets(rowInsets)
                    }
                }
            } header: {
                sectionHeader("Messages")
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            path.append(.chat(conversation.id))
        } label: {
            ConversationRow(
                conversation: conversation,
                connectionState: viewModel.connectionState(for: conversation)
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(IbangaColors.background)
        .listRowInsets(rowInsets)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(IbangaTypography.sectionHeader)
            .foregroundStyle(IbangaColors.textSecondary)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: IbangaSpacing.screenMargin, bottom: 0, trailing: IbangaSpacing.screenMargin)
    }

    // MARK: Chrome

    private var newConversationButton: some View {
        Button {
            isShowingPairing = true
        } label: {
            Image(systemName: IbangaIcons.plus)
                .font(.title2.weight(.semibold))
                .foregroundStyle(IbangaColors.onAccent)
                .frame(width: 56, height: 56)
                .background(IbangaColors.accent, in: .circle)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .padding(.trailing, IbangaSpacing.screenMargin)
        .padding(.bottom, IbangaSpacing.l)
        .accessibilityLabel("Connect device")
    }

    private var emptyState: some View {
        VStack(spacing: IbangaSpacing.xl) {
            BrandMark(size: 64)

            VStack(spacing: IbangaSpacing.s) {
                Text("Private conversations,\nwithout the noise.")
                    .font(IbangaTypography.title)
                    .foregroundStyle(IbangaColors.textPrimary)
                Text("Connect with a nearby device to get started.")
                    .font(IbangaTypography.callout)
                    .foregroundStyle(IbangaColors.textSecondary)
            }
            .multilineTextAlignment(.center)

            IbangaButton("Connect Device") {
                isShowingPairing = true
            }
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, IbangaSpacing.xxl)
    }
}

// MARK: - Rows

private struct ConversationRow: View {
    let conversation: Conversation
    let connectionState: SecureConnectionState

    private var hasUnread: Bool { conversation.unreadCount > 0 }

    var body: some View {
        HStack(spacing: IbangaSpacing.m) {
            PeerAvatar(name: conversation.peer.displayName)
                .overlay(alignment: .bottomTrailing) {
                    if connectionState == .secure {
                        Circle()
                            .fill(IbangaColors.secure)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(IbangaColors.background, lineWidth: 2))
                    }
                }

            VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                HStack(spacing: IbangaSpacing.xs) {
                    Text(conversation.peer.displayName)
                        .font(IbangaTypography.headline)
                        .foregroundStyle(IbangaColors.textPrimary)
                        .lineLimit(1)
                    if conversation.peer.isVerified {
                        Image(systemName: IbangaIcons.verified)
                            .font(.caption)
                            .foregroundStyle(IbangaColors.accent)
                            .accessibilityLabel("Verified")
                    }
                    Spacer(minLength: IbangaSpacing.s)
                    Text(ConversationTimestamp.string(for: conversation.lastActivityAt))
                        .font(IbangaTypography.caption.weight(hasUnread ? .semibold : .regular))
                        .foregroundStyle(hasUnread ? IbangaColors.accent : IbangaColors.textTertiary)
                }

                HStack(alignment: .top, spacing: IbangaSpacing.s) {
                    Text(preview)
                        .font(IbangaTypography.callout.weight(hasUnread ? .medium : .regular))
                        .foregroundStyle(hasUnread ? IbangaColors.textPrimary : IbangaColors.textSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if hasUnread {
                        UnreadBadge(count: conversation.unreadCount)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.vertical, IbangaSpacing.m)
        .contentShape(.rect)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: conversation.unreadCount)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    private var preview: String {
        guard let message = conversation.lastMessage else {
            return String(localized: "Secure conversation started")
        }
        return message.direction == .outgoing ? String(localized: "You: \(message.previewText)") : message.previewText
    }

    private var accessibilityValue: Text {
        let unread = hasUnread ? Text("\(conversation.unreadCount) unread") : Text("")
        let connection = connectionState == .secure ? Text("Connected securely") : Text("")
        return unread + Text(" ") + connection
    }
}

private struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(IbangaColors.onAccent)
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(IbangaColors.accent, in: .capsule)
            .contentTransition(.numericText())
            .accessibilityHidden(true)
    }
}

private struct MessageSearchRow: View {
    let message: Message
    let conversation: Conversation
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: IbangaSpacing.m) {
            PeerAvatar(name: conversation.peer.displayName, size: 40)
            VStack(alignment: .leading, spacing: IbangaSpacing.xxs) {
                HStack {
                    Text(conversation.peer.displayName)
                        .font(IbangaTypography.callout.weight(.semibold))
                        .foregroundStyle(IbangaColors.textPrimary)
                    Spacer(minLength: IbangaSpacing.s)
                    Text(ConversationTimestamp.string(for: message.sentAt))
                        .font(IbangaTypography.caption)
                        .foregroundStyle(IbangaColors.textTertiary)
                }
                Text(highlighted)
                    .font(IbangaTypography.callout)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, IbangaSpacing.m)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var highlighted: AttributedString {
        let prefix = message.direction == .outgoing ? String(localized: "You: ") : ""
        var text = AttributedString(prefix + (message.text ?? ""))
        if let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].foregroundColor = IbangaColors.textPrimary
            text[range].font = IbangaTypography.callout.weight(.semibold)
        }
        return text
    }
}

private enum ConversationTimestamp {
    static func string(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(.dateTime.hour().minute()) }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
