import SwiftUI

extension SecureConnectionState {
    var title: LocalizedStringKey {
        switch self {
        case .inactive: "Not connected"
        case .connecting: "Connecting…"
        case .establishingSession: "Establishing secure session…"
        case .secure: "Secure connection"
        case .failed: "Secure connection unavailable"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .secure: IbangaColors.secure
        case .connecting, .establishingSession: IbangaColors.warning
        case .failed: IbangaColors.danger
        case .inactive: IbangaColors.neutral
        }
    }

    var isInProgress: Bool {
        self == .connecting || self == .establishingSession
    }
}
