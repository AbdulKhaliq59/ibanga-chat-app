import SwiftUI

enum IbangaTypography {
    static let wordmark = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let display = Font.system(.title, design: .serif).weight(.semibold)
    static let title = Font.title3.weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let sectionHeader = Font.footnote.weight(.semibold)
    static let monospaced = Font.system(.callout, design: .monospaced)
}
