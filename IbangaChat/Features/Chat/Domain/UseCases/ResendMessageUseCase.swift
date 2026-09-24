import Foundation

struct ResendMessageUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ message: Message) async throws(ChatError) {
        guard message.direction == .outgoing, message.status == .failed else { return }
        guard sessions.connectionState(for: message.recipientID) == .secure else { throw .notSecure }

        try await chat.resend(messageID: message.id)
    }
}
