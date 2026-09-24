import SwiftUI

/// Screens owned by other features, supplied by the composition root.
struct ConversationsDestinations {
    let chat: (Conversation.ID) -> AnyView
    let security: () -> AnyView
    let pairing: (_ onConnected: @escaping (Conversation.ID) -> Void) -> AnyView
}

struct ConversationsView: View {
    private enum Route: Hashable {
        case chat(Conversation.ID)
        case security
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
                        path.append(.security)
                    } label: {
                        Image(systemName: IbangaIcons.shield)
                    }
                    .tint(IbangaColors.accent)
                    .accessibilityLabel("Security")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.conversations.isEmpty {
                    newConversationButton
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .chat(let id): destinations.chat(id)
                case .security: destinations.security()
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

    private var conversationList: some View {
        List(viewModel.conversations) { conversation in
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
            .listRowInsets(EdgeInsets(top: 0, leading: IbangaSpacing.screenMargin, bottom: 0, trailing: IbangaSpacing.screenMargin))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 56 }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.easeOut(duration: 0.25), value: viewModel.conversations.map(\.id))
    }

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
            Image(systemName: IbangaIcons.conversations)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(IbangaColors.textTertiary)
                .accessibilityHidden(true)

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

private struct ConversationRow: View {
    let conversation: Conversation
    let connectionState: SecureConnectionState

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
                    Text(Self.timestamp(for: conversation.lastActivityAt))
                        .font(IbangaTypography.caption)
                        .foregroundStyle(IbangaColors.textTertiary)
                }

                Text(preview)
                    .font(IbangaTypography.callout)
                    .foregroundStyle(IbangaColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, IbangaSpacing.m)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(connectionState == .secure ? Text("Connected securely") : Text(""))
    }

    private var preview: String {
        guard let message = conversation.lastMessage else {
            return String(localized: "Secure conversation started")
        }
        return message.direction == .outgoing ? String(localized: "You: \(message.text)") : message.text
    }

    private static func timestamp(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(.dateTime.hour().minute()) }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
