import Foundation
import SwiftData

@Model
final class AttachmentRecord {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var sealedMetadata: Data
    @Attribute(.externalStorage) var sealedContent: Data
    var message: MessageRecord?

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRawValue) ?? .file }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: MessageKind,
        sealedMetadata: SealedPayload,
        sealedContent: SealedPayload,
        message: MessageRecord
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.sealedMetadata = sealedMetadata.combined
        self.sealedContent = sealedContent.combined
        self.message = message
    }
}
