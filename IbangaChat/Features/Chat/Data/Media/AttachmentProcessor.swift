import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct AttachmentProcessor: AttachmentProcessing {
    private static let maximumImageDimension = 2048
    private static let maximumDecodedPixels = 100_000_000
    private static let jpegQuality = 0.82
    private static let maximumFilenameLength = 120
    private static let previewDirectory = FileManager.default.temporaryDirectory
        .appending(path: "IbangaPreview", directoryHint: .isDirectory)

    @concurrent
    func prepareImage(_ data: Data) async throws(AttachmentError) -> AttachmentDraft {
        guard !data.isEmpty else { throw .empty }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              hasSafeDimensions(source),
              let image = downsample(source, maxPixelSize: Self.maximumImageDimension)
        else { throw .unsupportedImage }

        // Only the pixels are written: EXIF, GPS and other source metadata are not carried over.
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw .unsupportedImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: Self.jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .unsupportedImage }

        let jpeg = output as Data
        guard jpeg.count <= Attachment.maximumByteCount else { throw .tooLarge }
        return AttachmentDraft(kind: .image, filename: "Photo.jpg", contentType: UTType.jpeg.identifier, data: jpeg)
    }

    @concurrent
    func prepareFile(at url: URL) async throws(AttachmentError) -> AttachmentDraft {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped { url.stopAccessingSecurityScopedResource() }
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isRegularFileKey])
        guard values?.isRegularFile != false else { throw .unreadable }
        if let size = values?.fileSize, size > Attachment.maximumByteCount { throw .tooLarge }

        guard let data = try? Data(contentsOf: url) else { throw .unreadable }
        guard !data.isEmpty else { throw .empty }
        guard data.count <= Attachment.maximumByteCount else { throw .tooLarge }

        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data
        return AttachmentDraft(
            kind: .file,
            filename: sanitizedFilename(url.lastPathComponent, type: type),
            contentType: type.identifier,
            data: data
        )
    }

    func validated(_ attachment: Attachment, data: Data) -> Attachment? {
        guard !data.isEmpty,
              data.count == attachment.byteCount,
              data.count <= Attachment.maximumByteCount
        else { return nil }

        let type = UTType(attachment.contentType) ?? .data
        switch attachment.kind {
        case .image:
            guard type.conforms(to: .image),
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  hasSafeDimensions(source)
            else { return nil }
        case .file:
            break
        case .text:
            return nil
        }

        return Attachment(
            id: attachment.id,
            kind: attachment.kind,
            filename: sanitizedFilename(attachment.filename, type: type),
            contentType: type.identifier,
            byteCount: data.count
        )
    }

    @concurrent
    func thumbnail(from data: Data, maxPixelSize: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              hasSafeDimensions(source)
        else { return nil }
        return downsample(source, maxPixelSize: maxPixelSize)
    }

    func makePreviewFile(for attachment: Attachment, data: Data) throws(AttachmentError) -> URL {
        let directory = Self.previewDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let type = UTType(attachment.contentType) ?? .data
        let url = directory.appending(path: sanitizedFilename(attachment.filename, type: type))
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            throw .unreadable
        }
    }

    func removePreviewFiles() {
        try? FileManager.default.removeItem(at: Self.previewDirectory)
    }

    // MARK: Private

    private func downsample(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Rejects undecodable images and decompression bombs before any pixels are allocated.
    private func hasSafeDimensions(_ source: CGImageSource) -> Bool {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return false }
        return width.multipliedReportingOverflow(by: height).partialValue <= Self.maximumDecodedPixels
    }

    /// Strips paths, control and bidirectional-override characters, and leading dots.
    private func sanitizedFilename(_ name: String, type: UTType) -> String {
        let lastComponent = (name as NSString).lastPathComponent
        var cleaned = String(String.UnicodeScalarView(
            lastComponent.unicodeScalars.filter { scalar in
                !CharacterSet.controlCharacters.contains(scalar) && scalar != "/" && scalar != ":"
            }
        ))
        .trimmingCharacters(in: .whitespacesAndNewlines)

        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        cleaned = String(cleaned.prefix(Self.maximumFilenameLength))

        if cleaned.isEmpty {
            let fileExtension = type.preferredFilenameExtension.map { ".\($0)" } ?? ""
            cleaned = "Attachment\(fileExtension)"
        }
        return cleaned
    }
}
