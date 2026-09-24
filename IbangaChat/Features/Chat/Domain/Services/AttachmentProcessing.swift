import CoreGraphics
import Foundation

nonisolated enum AttachmentError: Error, Equatable, Sendable {
    case unreadable
    case empty
    case tooLarge
    case unsupportedImage
}

nonisolated protocol AttachmentProcessing: Sendable {
    /// Re-encodes a photo for sending: bounded resolution, JPEG, and no EXIF/GPS metadata.
    @concurrent func prepareImage(_ data: Data) async throws(AttachmentError) -> AttachmentDraft
    /// Reads a user-selected file without modifying it.
    @concurrent func prepareFile(at url: URL) async throws(AttachmentError) -> AttachmentDraft
    /// Checks a received attachment against its declared metadata and returns sanitised metadata,
    /// or `nil` if it must be rejected.
    func validated(_ attachment: Attachment, data: Data) -> Attachment?
    @concurrent func thumbnail(from data: Data, maxPixelSize: Int) async -> CGImage?

    /// Writes decrypted bytes to a protected temporary file for Quick Look. Remove it after viewing.
    func makePreviewFile(for attachment: Attachment, data: Data) throws(AttachmentError) -> URL
    func removePreviewFiles()
}
