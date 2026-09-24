import Foundation

nonisolated struct Attachment: Identifiable, Codable, Hashable, Sendable {
    static let maximumByteCount = 25 * 1024 * 1024

    let id: UUID
    let kind: MessageKind
    let filename: String
    /// Uniform Type Identifier, e.g. `public.jpeg`.
    let contentType: String
    let byteCount: Int
}

/// An attachment chosen by the user, prepared and ready to be encrypted and sent.
nonisolated struct AttachmentDraft: Hashable, Sendable {
    let kind: MessageKind
    let filename: String
    let contentType: String
    let data: Data
}
