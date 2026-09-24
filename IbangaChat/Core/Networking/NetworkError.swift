import Foundation

nonisolated enum NetworkError: Error, Equatable, Sendable {
    case deviceUnavailable
    case connectionUnavailable
    case packetTooLarge
    case malformedPacket
    case sendFailed

    var logCode: String {
        switch self {
        case .deviceUnavailable: "device-unavailable"
        case .connectionUnavailable: "connection-unavailable"
        case .packetTooLarge: "packet-too-large"
        case .malformedPacket: "malformed-packet"
        case .sendFailed: "send-failed"
        }
    }
}
