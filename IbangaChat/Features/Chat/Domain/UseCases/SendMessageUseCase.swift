import Foundation

struct SendMessageUseCase {
    static let maximumLength = 4000

    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ text: String, in conversationID: Conversation.ID) async throws(ChatError) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .emptyMessage }
        guard trimmed.count <= Self.maximumLength else { throw .messageTooLong }
        guard let conversation = chat.conversation(id: conversationID) else { throw .conversationNotFound }
        guard sessions.connectionState(for: conversation.peer.id) == .secure else { throw .notSecure }

        try await chat.sendText(trimmed, in: conversationID)
    }
}
