import SwiftUI
import UIKit

enum IbangaColors {
    static let accent = Color(light: 0x1F5C4F, dark: 0x6CCBB0)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0B0C0E)
    static let accentSoft = Color(light: 0xE3EEEA, dark: 0x16302A)

    static let background = Color(light: 0xF7F7F5, dark: 0x0B0C0E)
    static let surface = Color(light: 0xFFFFFF, dark: 0x16181B)
    static let separator = Color(light: 0xE4E4E0, dark: 0x26292D)

    static let textPrimary = Color(light: 0x111214, dark: 0xF2F2F0)
    static let textSecondary = Color(light: 0x5E6166, dark: 0x9A9DA3)
    static let textTertiary = Color(light: 0x8A8D92, dark: 0x6E7176)

    static let secure = accent
    static let neutral = Color(light: 0x9A9DA3, dark: 0x5E6166)
    static let warning = Color(light: 0xA15C00, dark: 0xF0B34A)
    static let danger = Color(light: 0xB3261E, dark: 0xF2766B)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
