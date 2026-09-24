import Foundation

struct SendAttachmentUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ draft: AttachmentDraft, in conversationID: Conversation.ID) async throws(ChatError) {
        guard !draft.data.isEmpty else { throw .emptyMessage }
        guard draft.data.count <= Attachment.maximumByteCount else { throw .messageTooLong }
        guard let conversation = chat.conversation(id: conversationID) else { throw .conversationNotFound }
        guard sessions.connectionState(for: conversation.peer.id) == .secure else { throw .notSecure }

        try await chat.sendAttachment(draft, in: conversationID)
    }
}
