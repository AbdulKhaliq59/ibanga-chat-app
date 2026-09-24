import Foundation
import UniformTypeIdentifiers

enum AttachmentFormatting {
    static func symbolName(for contentType: String) -> String {
        guard let type = UTType(contentType) else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .spreadsheet) { return "tablecells" }
        if type.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    static func typeDescription(for contentType: String) -> String {
        guard let type = UTType(contentType) else { return String(localized: "File") }
        return type.preferredFilenameExtension?.uppercased() ?? type.localizedDescription ?? String(localized: "File")
    }

    static func size(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    static func summary(contentType: String, byteCount: Int) -> String {
        "\(typeDescription(for: contentType)) · \(size(byteCount))"
    }
}
