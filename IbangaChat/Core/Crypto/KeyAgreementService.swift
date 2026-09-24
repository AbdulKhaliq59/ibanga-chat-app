import CryptoKit
import Foundation

nonisolated protocol KeyAgreementServiceProtocol: Sendable {
    func sharedSecret(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SharedSecret

    func deriveSessionKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SymmetricKey
}

nonisolated struct KeyAgreementService: KeyAgreementServiceProtocol {
    static let sessionKeyInfo = Data("IbangaChat/v1/session-key".utf8)
    private static let transcriptLabel = Data("IbangaChat/v1/transcript".utf8)
    private static let sessionKeyByteCount = 32

    func sharedSecret(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SharedSecret {
        let secret: SharedSecret
        do {
            secret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        } catch {
            throw .keyAgreementFailed
        }

        let isAllZero = secret.withUnsafeBytes { bytes in bytes.allSatisfy { $0 == 0 } }
        guard !isAllZero else { throw .invalidPeerPublicKey }
        return secret
    }

    func deriveSessionKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SymmetricKey {
        let localPublicKey = privateKey.publicKey.rawRepresentation
        let remotePublicKey = peerPublicKey.rawRepresentation
        guard localPublicKey != remotePublicKey else { throw .invalidPeerPublicKey }

        let secret = try sharedSecret(privateKey: privateKey, peerPublicKey: peerPublicKey)
        return secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Self.transcriptSalt(localPublicKey, remotePublicKey),
            sharedInfo: Self.sessionKeyInfo,
            outputByteCount: Self.sessionKeyByteCount
        )
    }

    static func transcriptSalt(_ first: Data, _ second: Data) -> Data {
        let (lower, higher) = first.lexicographicallyPrecedes(second) ? (first, second) : (second, first)
        var hasher = SHA256()
        hasher.update(data: transcriptLabel)
        hasher.update(data: lower)
        hasher.update(data: higher)
        return Data(hasher.finalize())
    }
}
