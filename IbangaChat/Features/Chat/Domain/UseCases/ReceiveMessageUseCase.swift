import Foundation

struct ReceiveMessageUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol
    let attachments: any AttachmentProcessing

    func callAsFunction(_ envelope: IncomingEnvelope) async {
        switch envelope.payload {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= SendMessageUseCase.maximumLength else { return }
            await store(.text(trimmed), attachmentData: nil, from: envelope)

        case let .attachment(attachment, data):
            // Decrypt → validate → store. Anything that does not match its declared metadata is dropped.
            guard let validated = attachments.validated(attachment, data: data) else { return }
            await store(.attachment(validated), attachmentData: data, from: envelope)

        case .receipt(let messageID):
            chat.markDelivered(messageID: messageID, by: envelope.peerID)
        }
    }

    private func store(_ content: MessageContent, attachmentData: Data?, from envelope: IncomingEnvelope) async {
        do {
            _ = try await chat.storeIncoming(content, attachmentData: attachmentData, from: envelope)
        } catch {
            return
        }
        try? await sessions.send(
            .receipt(messageID: envelope.messageID),
            messageID: UUID(),
            sentAt: .now,
            to: envelope.peerID
        )
    }
}
