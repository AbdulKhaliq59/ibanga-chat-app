import Foundation

nonisolated enum MessageContent: Codable, Hashable, Sendable {
    case text(String)
    case attachment(Attachment)

    var kind: MessageKind {
        switch self {
        case .text: .text
        case .attachment(let attachment): attachment.kind
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
    var isUnread = false

    var kind: MessageKind { content.kind }

    var text: String? {
        if case .text(let text) = content { return text }
        return nil
    }

    var attachment: Attachment? {
        if case .attachment(let attachment) = content { return attachment }
        return nil
    }

    var previewText: String {
        switch content {
        case .text(let text): text
        case .attachment(let attachment): attachment.kind == .image ? String(localized: "📷 Photo") : "📎 \(attachment.filename)"
        }
    }
}

/// What travels inside an encrypted session. Never transmitted outside `EncryptedMessage`.
nonisolated enum SessionPayload: Codable, Hashable, Sendable {
    case text(String)
    case attachment(Attachment, data: Data)
    case receipt(messageID: UUID)
}

/// A message received over a secure session, already authenticated and decrypted.
nonisolated struct IncomingEnvelope: Sendable {
    let peerID: Peer.ID
    let messageID: UUID
    let sentAt: Date
    let payload: SessionPayload
}
