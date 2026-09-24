import CryptoKit
import Foundation

nonisolated enum HandshakeRole: UInt8, Sendable {
    case lower = 0
    case higher = 1

    var peer: HandshakeRole { self == .lower ? .higher : .lower }
}

nonisolated struct SessionKeyMaterial: Sendable {
    let sendingKey: SymmetricKey
    let receivingKey: SymmetricKey
    let confirmationKey: SymmetricKey
    let transcript: Data
    let localRole: HandshakeRole
}

nonisolated protocol KeyAgreementServiceProtocol: Sendable {
    func sharedSecret(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SharedSecret

    func deriveSessionKeys(
        localIdentity: Curve25519.KeyAgreement.PrivateKey,
        localEphemeral: Curve25519.KeyAgreement.PrivateKey,
        remoteIdentity: Curve25519.KeyAgreement.PublicKey,
        remoteEphemeral: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SessionKeyMaterial

    func confirmationTag(for role: HandshakeRole, in material: SessionKeyMaterial) -> Data
    func isValidConfirmationTag(_ tag: Data, for role: HandshakeRole, in material: SessionKeyMaterial) -> Bool
}

nonisolated struct KeyAgreementService: KeyAgreementServiceProtocol {
    private static let transcriptLabel = Data("IbangaChat/v1/handshake-transcript".utf8)
    private static let lowerToHigherInfo = Data("IbangaChat/v1/key/lower-to-higher".utf8)
    private static let higherToLowerInfo = Data("IbangaChat/v1/key/higher-to-lower".utf8)
    private static let confirmationInfo = Data("IbangaChat/v1/key/confirmation".utf8)
    private static let confirmationLabel = Data("IbangaChat/v1/key-confirmation".utf8)
    private static let keyByteCount = 32

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

    func deriveSessionKeys(
        localIdentity: Curve25519.KeyAgreement.PrivateKey,
        localEphemeral: Curve25519.KeyAgreement.PrivateKey,
        remoteIdentity: Curve25519.KeyAgreement.PublicKey,
        remoteEphemeral: Curve25519.KeyAgreement.PublicKey
    ) throws(CryptoError) -> SessionKeyMaterial {
        let localIdentityKey = localIdentity.publicKey.rawRepresentation
        let remoteIdentityKey = remoteIdentity.rawRepresentation
        guard localIdentityKey != remoteIdentityKey else { throw .invalidPeerPublicKey }

        let ephemeralSecret = try sharedSecret(privateKey: localEphemeral, peerPublicKey: remoteEphemeral)
        let identitySecret = try sharedSecret(privateKey: localIdentity, peerPublicKey: remoteIdentity)

        let localRole: HandshakeRole = localIdentityKey.lexicographicallyPrecedes(remoteIdentityKey) ? .lower : .higher
        let local = (localIdentityKey, localEphemeral.publicKey.rawRepresentation)
        let remote = (remoteIdentityKey, remoteEphemeral.rawRepresentation)
        let (lower, higher) = localRole == .lower ? (local, remote) : (remote, local)

        var transcriptHasher = SHA256()
        transcriptHasher.update(data: Self.transcriptLabel)
        transcriptHasher.update(data: lower.0)
        transcriptHasher.update(data: lower.1)
        transcriptHasher.update(data: higher.0)
        transcriptHasher.update(data: higher.1)
        let transcript = Data(transcriptHasher.finalize())

        var inputKeyMaterial = ephemeralSecret.withUnsafeBytes { Data($0) }
        inputKeyMaterial.append(identitySecret.withUnsafeBytes { Data($0) })

        let pseudoRandomKey = HKDF<SHA256>.extract(inputKeyMaterial: SymmetricKey(data: inputKeyMaterial), salt: transcript)
        let lowerToHigher = HKDF<SHA256>.expand(pseudoRandomKey: pseudoRandomKey, info: Self.lowerToHigherInfo, outputByteCount: Self.keyByteCount)
        let higherToLower = HKDF<SHA256>.expand(pseudoRandomKey: pseudoRandomKey, info: Self.higherToLowerInfo, outputByteCount: Self.keyByteCount)
        let confirmation = HKDF<SHA256>.expand(pseudoRandomKey: pseudoRandomKey, info: Self.confirmationInfo, outputByteCount: Self.keyByteCount)

        return SessionKeyMaterial(
            sendingKey: localRole == .lower ? lowerToHigher : higherToLower,
            receivingKey: localRole == .lower ? higherToLower : lowerToHigher,
            confirmationKey: confirmation,
            transcript: transcript,
            localRole: localRole
        )
    }

    func confirmationTag(for role: HandshakeRole, in material: SessionKeyMaterial) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: confirmationMessage(for: role, in: material), using: material.confirmationKey))
    }

    func isValidConfirmationTag(_ tag: Data, for role: HandshakeRole, in material: SessionKeyMaterial) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(
            tag,
            authenticating: confirmationMessage(for: role, in: material),
            using: material.confirmationKey
        )
    }

    private func confirmationMessage(for role: HandshakeRole, in material: SessionKeyMaterial) -> Data {
        var message = Self.confirmationLabel
        message.append(role.rawValue)
        message.append(material.transcript)
        return message
    }
}
