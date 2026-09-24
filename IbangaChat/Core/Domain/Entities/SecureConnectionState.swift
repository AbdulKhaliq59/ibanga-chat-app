import Foundation

nonisolated enum SecureConnectionState: Equatable, Sendable {
    case inactive
    case connecting
    case establishingSession
    case secure
    case failed
}
