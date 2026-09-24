import Foundation
import SwiftData

@Model
final class MessageRecord {
    @Attribute(.unique) var id: UUID
    var directionRawValue: String
    var kindRawValue: String
    var statusRawValue: String
    var sentAt: Date
    var sealedBody: Data
    var conversation: ConversationRecord?

    @Relationship(deleteRule: .cascade, inverse: \AttachmentRecord.message)
    var attachments: [AttachmentRecord] = []

    var direction: MessageDirection {
        get { MessageDirection(rawValue: directionRawValue) ?? .incoming }
        set { directionRawValue = newValue.rawValue }
    }

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }

    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRawValue) ?? .failed }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        direction: MessageDirection,
        kind: MessageKind,
        status: MessageStatus,
        sentAt: Date,
        sealedBody: SealedPayload,
        conversation: ConversationRecord
    ) {
        self.id = id
        self.directionRawValue = direction.rawValue
        self.kindRawValue = kind.rawValue
        self.statusRawValue = status.rawValue
        self.sentAt = sentAt
        self.sealedBody = sealedBody.combined
        self.conversation = conversation
    }
}
