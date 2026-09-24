import Foundation
import SwiftData

/// Attachment bytes, sealed with the device storage key. Metadata lives in the owning message's sealed body.
@Model
final class AttachmentRecord {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    @Attribute(.externalStorage) var sealedContent: Data
    var message: MessageRecord?

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRawValue) ?? .file }
        set { kindRawValue = newValue.rawValue }
    }

    init(id: UUID, kind: MessageKind, sealedContent: SealedPayload, message: MessageRecord) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.sealedContent = sealedContent.combined
        self.message = message
    }
}
