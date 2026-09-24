import Foundation

nonisolated enum SessionError: Error, Equatable, Sendable {
    case notConnected
    case peerUnavailable
    case connectionFailed
    case handshakeFailed
    case identityMismatch
    case incompatibleVersion
    case timedOut
    case encryptionFailed
    case transmissionFailed
    case protocolViolation
    case messageRejected

    var logCode: String {
        switch self {
        case .notConnected: "not-connected"
        case .peerUnavailable: "peer-unavailable"
        case .connectionFailed: "connection-failed"
        case .handshakeFailed: "handshake-failed"
        case .identityMismatch: "identity-mismatch"
        case .incompatibleVersion: "incompatible-version"
        case .timedOut: "timed-out"
        case .encryptionFailed: "encryption-failed"
        case .transmissionFailed: "transmission-failed"
        case .protocolViolation: "protocol-violation"
        case .messageRejected: "message-rejected"
        }
    }
}

nonisolated enum ChatError: Error, Equatable, Sendable {
    case emptyMessage
    case messageTooLong
    case notSecure
    case conversationNotFound
    case storageFailed
    case sendFailed(SessionError)
}
