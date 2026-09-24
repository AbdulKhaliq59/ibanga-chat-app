import Foundation

nonisolated enum MessageContent: Codable, Hashable, Sendable {
    case text(String)

    var kind: MessageKind {
        switch self {
        case .text: .text
        }
    }
}

nonisolated struct Message: Identifiable, Hashable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: Peer.ID
    let recipientID: Peer.ID
    let direction: MessageDirection
    let content: MessageContent
    let sentAt: Date
    var status: MessageStatus

    var kind: MessageKind { content.kind }

    var text: String {
        switch content {
        case .text(let text): text
        }
    }
}

/// What travels inside an encrypted session. Never transmitted outside `EncryptedMessage`.
nonisolated enum SessionPayload: Codable, Hashable, Sendable {
    case text(String)
    case receipt(messageID: UUID)
}

/// A message received over a secure session, already authenticated and decrypted.
nonisolated struct IncomingEnvelope: Sendable {
    let peerID: Peer.ID
    let messageID: UUID
    let sentAt: Date
    let payload: SessionPayload
}
