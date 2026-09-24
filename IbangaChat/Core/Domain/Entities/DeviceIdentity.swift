import Foundation

nonisolated struct DeviceIdentity: Equatable, Sendable {
    /// Raw 32-byte X25519 public key.
    let publicKey: Data
    /// Hex-encoded SHA-256 prefix of `publicKey`, used for human comparison.
    let fingerprint: String
}
