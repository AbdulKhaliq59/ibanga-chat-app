import Foundation

struct ReceiveMessageUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ envelope: IncomingEnvelope) async {
        switch envelope.payload {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= SendMessageUseCase.maximumLength else { return }

            do {
                _ = try await chat.storeIncomingText(trimmed, from: envelope)
            } catch {
                return
            }
            try? await sessions.send(
                .receipt(messageID: envelope.messageID),
                messageID: UUID(),
                sentAt: .now,
                to: envelope.peerID
            )

        case .receipt(let messageID):
            chat.markDelivered(messageID: messageID, by: envelope.peerID)
        }
    }
}
