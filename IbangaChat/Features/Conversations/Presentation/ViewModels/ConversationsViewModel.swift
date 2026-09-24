import Foundation
import Observation

@Observable
final class ConversationsViewModel {
    private let chat: any ChatRepositoryProtocol
    private let sessions: any SessionRepositoryProtocol

    init(chat: any ChatRepositoryProtocol, sessions: any SessionRepositoryProtocol) {
        self.chat = chat
        self.sessions = sessions
    }

    var conversations: [Conversation] { chat.conversations }

    func connectionState(for conversation: Conversation) -> SecureConnectionState {
        sessions.connectionState(for: conversation.peer.id)
    }
}
