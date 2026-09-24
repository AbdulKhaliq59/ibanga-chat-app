import CryptoKit
import Foundation

nonisolated struct HandshakeOffer: Codable, Equatable, Sendable {
    let identityKey: Data
    let ephemeralKey: Data
}

/// Our half of an in-progress handshake. The ephemeral private key is only readable by `CryptoService`.
nonisolated struct PendingHandshake: Sendable, CustomStringConvertible {
    fileprivate let ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey
    let offer: HandshakeOffer

    var description: String { "PendingHandshake(<redacted>)" }
}

/// Keys for one authenticated connection. Opaque outside the crypto core.
nonisolated struct SecureSession: Sendable, CustomStringConvertible {
    fileprivate let material: SessionKeyMaterial
    let peerIdentityKey: Data
    let peerFingerprint: String

    var description: String { "SecureSession(peer: \(peerFingerprint), keys: <redacted>)" }
}

nonisolated protocol CryptoServiceProtocol: Sendable {
    func loadIdentity() async throws(CryptoError) -> DeviceIdentity?
    func createIdentity() async throws(CryptoError) -> DeviceIdentity
    func destroyIdentity() async throws(CryptoError)

    func beginHandshake() async throws(CryptoError) -> PendingHandshake
    func completeHandshake(_ pending: PendingHandshake, peerOffer: HandshakeOffer) async throws(CryptoError) -> SecureSession
    func confirmationTag(for session: SecureSession) async -> Data
    func verifyPeerConfirmation(_ tag: Data, for session: SecureSession) async throws(CryptoError)

    func seal(_ plaintext: Data, in session: SecureSession, associatedData: Data) async throws(CryptoError) -> SealedPayload
    func open(_ payload: SealedPayload, in session: SecureSession, associatedData: Data) async throws(CryptoError) -> Data

    func sealForStorage(_ plaintext: Data, associatedData: Data) async throws(CryptoError) -> SealedPayload
    func openFromStorage(_ payload: SealedPayload, associatedData: Data) async throws(CryptoError) -> Data

    func verificationCode(peerIdentityKey: Data) async throws(CryptoError) -> String
}

actor CryptoService: CryptoServiceProtocol {
    private static let verificationLabel = Data("IbangaChat/v1/verification-code".utf8)

    private let keychain: any KeychainServiceProtocol
    private let keyAgreement: any KeyAgreementServiceProtocol
    private let encryption: any EncryptionServiceProtocol
    private let logger: SecureLogger

    private var cachedPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var cachedStorageKey: SymmetricKey?

    init(
        keychain: any KeychainServiceProtocol,
        keyAgreement: any KeyAgreementServiceProtocol = KeyAgreementService(),
        encryption: any EncryptionServiceProtocol = EncryptionService(),
        logger: SecureLogger
    ) {
        self.keychain = keychain
        self.keyAgreement = keyAgreement
        self.encryption = encryption
        self.logger = logger
    }

    // MARK: Identity

    func loadIdentity() throws(CryptoError) -> DeviceIdentity? {
        guard let privateKey = try storedPrivateKey() else { return nil }
        logger.log(.identityLoaded)
        return Self.identity(for: privateKey.publicKey)
    }

    func createIdentity() throws(CryptoError) -> DeviceIdentity {
        if let existing = try storedPrivateKey() {
            return Self.identity(for: existing.publicKey)
        }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        do {
            try keychain.save(privateKey.rawRepresentation, for: .identityPrivateKey)
        } catch {
            logger.log(.failure(.keychain, code: error.logCode))
            throw .keychain(error)
        }

        cachedPrivateKey = privateKey
        logger.log(.identityCreated)
        return Self.identity(for: privateKey.publicKey)
    }

    func destroyIdentity() throws(CryptoError) {
        cachedPrivateKey = nil
        cachedStorageKey = nil
        do {
            try keychain.delete(.identityPrivateKey)
            try keychain.delete(.storageKey)
        } catch {
            logger.log(.failure(.keychain, code: error.logCode))
            throw .keychain(error)
        }
        logger.log(.identityDestroyed)
    }

    // MARK: Handshake

    func beginHandshake() throws(CryptoError) -> PendingHandshake {
        guard let identityKey = try storedPrivateKey() else { throw .identityUnavailable }
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        return PendingHandshake(
            ephemeralPrivateKey: ephemeralKey,
            offer: HandshakeOffer(
                identityKey: identityKey.publicKey.rawRepresentation,
                ephemeralKey: ephemeralKey.publicKey.rawRepresentation
            )
        )
    }

    func completeHandshake(_ pending: PendingHandshake, peerOffer: HandshakeOffer) throws(CryptoError) -> SecureSession {
        guard let identityKey = try storedPrivateKey() else { throw .identityUnavailable }

        let remoteIdentity: Curve25519.KeyAgreement.PublicKey
        let remoteEphemeral: Curve25519.KeyAgreement.PublicKey
        do {
            remoteIdentity = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerOffer.identityKey)
            remoteEphemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerOffer.ephemeralKey)
        } catch {
            throw .invalidPeerPublicKey
        }

        do {
            let material = try keyAgreement.deriveSessionKeys(
                localIdentity: identityKey,
                localEphemeral: pending.ephemeralPrivateKey,
                remoteIdentity: remoteIdentity,
                remoteEphemeral: remoteEphemeral
            )
            return SecureSession(
                material: material,
                peerIdentityKey: peerOffer.identityKey,
                peerFingerprint: Self.fingerprint(of: peerOffer.identityKey)
            )
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
    }

    func confirmationTag(for session: SecureSession) -> Data {
        keyAgreement.confirmationTag(for: session.material.localRole, in: session.material)
    }

    func verifyPeerConfirmation(_ tag: Data, for session: SecureSession) throws(CryptoError) {
        guard keyAgreement.isValidConfirmationTag(tag, for: session.material.localRole.peer, in: session.material) else {
            logger.log(.failure(.crypto, code: CryptoError.authenticationFailed.logCode))
            throw .authenticationFailed
        }
        logger.log(.sessionEstablished)
    }

    // MARK: Transport encryption

    func seal(_ plaintext: Data, in session: SecureSession, associatedData: Data) throws(CryptoError) -> SealedPayload {
        do {
            return try encryption.seal(plaintext, using: session.material.sendingKey, authenticating: associatedData)
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
    }

    func open(_ payload: SealedPayload, in session: SecureSession, associatedData: Data) throws(CryptoError) -> Data {
        do {
            return try encryption.open(payload, using: session.material.receivingKey, authenticating: associatedData)
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
    }

    // MARK: Storage encryption

    func sealForStorage(_ plaintext: Data, associatedData: Data) throws(CryptoError) -> SealedPayload {
        try encryption.seal(plaintext, using: try storageKey(), authenticating: associatedData)
    }

    func openFromStorage(_ payload: SealedPayload, associatedData: Data) throws(CryptoError) -> Data {
        do {
            return try encryption.open(payload, using: try storageKey(), authenticating: associatedData)
        } catch {
            logger.log(.failure(.persistence, code: error.logCode))
            throw error
        }
    }

    // MARK: Verification

    /// A 12-digit code derived from both identity keys. Identical on both devices, stable across connections.
    func verificationCode(peerIdentityKey: Data) throws(CryptoError) -> String {
        guard let identityKey = try storedPrivateKey() else { throw .identityUnavailable }
        let localKey = identityKey.publicKey.rawRepresentation
        let (lower, higher) = localKey.lexicographicallyPrecedes(peerIdentityKey)
            ? (localKey, peerIdentityKey)
            : (peerIdentityKey, localKey)

        var hasher = SHA256()
        hasher.update(data: Self.verificationLabel)
        hasher.update(data: lower)
        hasher.update(data: higher)
        let value = hasher.finalize().prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) } % 1_000_000_000_000

        let digits = String(format: "%012llu", value)
        return stride(from: 0, to: 12, by: 3)
            .map { offset in
                let start = digits.index(digits.startIndex, offsetBy: offset)
                return String(digits[start..<digits.index(start, offsetBy: 3)])
            }
            .joined(separator: " ")
    }

    // MARK: Private

    private func storedPrivateKey() throws(CryptoError) -> Curve25519.KeyAgreement.PrivateKey? {
        if let cachedPrivateKey { return cachedPrivateKey }

        let keyData: Data
        do {
            keyData = try keychain.read(.identityPrivateKey)
        } catch .itemNotFound {
            return nil
        } catch {
            logger.log(.failure(.keychain, code: error.logCode))
            throw .keychain(error)
        }

        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
            cachedPrivateKey = privateKey
            return privateKey
        } catch {
            logger.log(.failure(.crypto, code: CryptoError.invalidKeyMaterial.logCode))
            throw .invalidKeyMaterial
        }
    }

    private func storageKey() throws(CryptoError) -> SymmetricKey {
        if let cachedStorageKey { return cachedStorageKey }

        do {
            let key = SymmetricKey(data: try keychain.read(.storageKey))
            guard key.bitCount == 256 else { throw CryptoError.invalidKeyMaterial }
            cachedStorageKey = key
            return key
        } catch KeychainError.itemNotFound {
            let key = SymmetricKey(size: .bits256)
            do {
                try keychain.save(key.withUnsafeBytes { Data($0) }, for: .storageKey)
            } catch {
                logger.log(.failure(.keychain, code: error.logCode))
                throw .keychain(error)
            }
            cachedStorageKey = key
            return key
        } catch let error as KeychainError {
            logger.log(.failure(.keychain, code: error.logCode))
            throw .keychain(error)
        } catch {
            throw .invalidKeyMaterial
        }
    }

    private static func identity(for publicKey: Curve25519.KeyAgreement.PublicKey) -> DeviceIdentity {
        let publicKeyData = publicKey.rawRepresentation
        return DeviceIdentity(publicKey: publicKeyData, fingerprint: fingerprint(of: publicKeyData))
    }

    static func fingerprint(of publicKey: Data) -> String {
        Data(SHA256.hash(data: publicKey).prefix(16)).hexString
    }
}
