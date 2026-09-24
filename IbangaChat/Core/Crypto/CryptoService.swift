//
//  CryptoService.swift
//  IbangaChat
//

import CryptoKit
import Foundation

/// A derived symmetric key for one peer relationship.
///
/// Opaque outside the crypto core: it can only be handed back to `CryptoService`.
/// Its descriptions are redacted so it cannot leak through logging or debugging output.
nonisolated struct SessionKey: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    fileprivate let key: SymmetricKey
    let peerPublicKey: Data

    var description: String { "SessionKey(<redacted>)" }
    var debugDescription: String { description }
}

/// The application's single entry point to cryptography.
///
/// The device's private key never leaves this type: callers work with public
/// identities, opaque session keys and sealed payloads only.
nonisolated protocol CryptoServiceProtocol: Sendable {
    /// Returns the existing device identity, or `nil` if none has been created.
    func loadIdentity() async throws(CryptoError) -> DeviceIdentity?
    /// Creates the device identity. If one already exists it is returned unchanged.
    func createIdentity() async throws(CryptoError) -> DeviceIdentity
    /// Permanently removes the device identity from the Keychain.
    func destroyIdentity() async throws(CryptoError)

    func establishSession(withPeerPublicKey peerPublicKey: Data) async throws(CryptoError) -> SessionKey
    func encrypt(_ plaintext: Data, in session: SessionKey, associatedData: Data) async throws(CryptoError) -> SealedPayload
    func decrypt(_ payload: SealedPayload, in session: SessionKey, associatedData: Data) async throws(CryptoError) -> Data
}

/// An actor so the cached private key is isolated and all crypto runs off the main thread.
actor CryptoService: CryptoServiceProtocol {
    private let keychain: any KeychainServiceProtocol
    private let keyAgreement: any KeyAgreementServiceProtocol
    private let encryption: any EncryptionServiceProtocol
    private let logger: SecureLogger

    private var cachedPrivateKey: Curve25519.KeyAgreement.PrivateKey?

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
        // Never replace an identity that already exists.
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
        do {
            try keychain.delete(.identityPrivateKey)
        } catch {
            logger.log(.failure(.keychain, code: error.logCode))
            throw .keychain(error)
        }
        logger.log(.identityDestroyed)
    }

    // MARK: Sessions

    func establishSession(withPeerPublicKey peerPublicKey: Data) throws(CryptoError) -> SessionKey {
        guard let privateKey = try storedPrivateKey() else { throw .identityUnavailable }

        let peerKey: Curve25519.KeyAgreement.PublicKey
        do {
            peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        } catch {
            throw .invalidPeerPublicKey
        }

        do {
            let key = try keyAgreement.deriveSessionKey(privateKey: privateKey, peerPublicKey: peerKey)
            logger.log(.sessionEstablished)
            return SessionKey(key: key, peerPublicKey: peerPublicKey)
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
    }

    // MARK: Encryption

    func encrypt(_ plaintext: Data, in session: SessionKey, associatedData: Data) throws(CryptoError) -> SealedPayload {
        do {
            return try encryption.seal(plaintext, using: session.key, authenticating: associatedData)
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
    }

    func decrypt(_ payload: SealedPayload, in session: SessionKey, associatedData: Data) throws(CryptoError) -> Data {
        do {
            return try encryption.open(payload, using: session.key, authenticating: associatedData)
        } catch {
            logger.log(.failure(.crypto, code: error.logCode))
            throw error
        }
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

        // Corrupt key material fails closed: we never silently mint a replacement identity.
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
            cachedPrivateKey = privateKey
            return privateKey
        } catch {
            logger.log(.failure(.crypto, code: CryptoError.invalidKeyMaterial.logCode))
            throw .invalidKeyMaterial
        }
    }

    private static func identity(for publicKey: Curve25519.KeyAgreement.PublicKey) -> DeviceIdentity {
        let publicKeyData = publicKey.rawRepresentation
        return DeviceIdentity(publicKey: publicKeyData, fingerprint: fingerprint(of: publicKeyData))
    }

    /// First 128 bits of SHA-256 over the public key, hex encoded.
    static func fingerprint(of publicKey: Data) -> String {
        Data(SHA256.hash(data: publicKey).prefix(16)).hexString
    }
}
