import Foundation

nonisolated enum CryptoError: Error, Equatable, Sendable {
    case identityUnavailable
    case invalidKeyMaterial
    case invalidPeerPublicKey
    case keyAgreementFailed
    case encryptionFailed
    case malformedPayload
    case authenticationFailed
    case keychain(KeychainError)
}

nonisolated extension CryptoError {
    var logCode: String {
        switch self {
        case .identityUnavailable: "identity-unavailable"
        case .invalidKeyMaterial: "invalid-key-material"
        case .invalidPeerPublicKey: "invalid-peer-public-key"
        case .keyAgreementFailed: "key-agreement-failed"
        case .encryptionFailed: "encryption-failed"
        case .malformedPayload: "malformed-payload"
        case .authenticationFailed: "authentication-failed"
        case .keychain(let error): "keychain-\(error.logCode)"
        }
    }
}
