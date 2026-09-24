import Foundation
import Observation

@Observable
final class ConversationsViewModel {
    private static let searchDebounce: Duration = .milliseconds(250)

    var searchText = ""
    private(set) var messageResults: [Message] = []

    private let chat: any ChatRepositoryProtocol
    private let sessions: any SessionRepositoryProtocol

    init(chat: any ChatRepositoryProtocol, sessions: any SessionRepositoryProtocol) {
        self.chat = chat
        self.sessions = sessions
    }

    var conversations: [Conversation] { chat.conversations }

    var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !query.isEmpty }

    var matchingConversations: [Conversation] {
        guard isSearching else { return conversations }
        return conversations.filter { $0.peer.displayName.localizedStandardContains(query) }
    }

    func connectionState(for conversation: Conversation) -> SecureConnectionState {
        sessions.connectionState(for: conversation.peer.id)
    }

    func conversation(for message: Message) -> Conversation? {
        chat.conversation(id: message.conversationID)
    }

    func search() async {
        let query = query
        guard !query.isEmpty else {
            messageResults = []
            return
        }

        try? await Task.sleep(for: Self.searchDebounce)
        guard !Task.isCancelled else { return }

        let results = await chat.searchMessages(matching: query)
        guard !Task.isCancelled else { return }
        messageResults = results
    }
}
