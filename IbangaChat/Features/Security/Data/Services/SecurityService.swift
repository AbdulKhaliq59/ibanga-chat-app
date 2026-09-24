import CryptoKit
import Foundation

nonisolated struct SecurityService: SecurityServiceProtocol {
    private let crypto: any CryptoServiceProtocol
    private let keychain: any KeychainServiceProtocol
    private let keyAgreement: KeyAgreementService
    private let encryption: EncryptionService
    private let logger: SecureLogger

    init(
        crypto: any CryptoServiceProtocol,
        keychain: any KeychainServiceProtocol,
        keyAgreement: KeyAgreementService = KeyAgreementService(),
        encryption: EncryptionService = EncryptionService(),
        logger: SecureLogger
    ) {
        self.crypto = crypto
        self.keychain = keychain
        self.keyAgreement = keyAgreement
        self.encryption = encryption
        self.logger = logger
    }

    @concurrent
    func runDiagnostics() async -> SecurityReport {
        let identityStored = await verifyIdentityKeyStorage()
        let checks: [SecurityCheck] = SecurityCheck.Kind.allCases.map { kind in
            let passed = switch kind {
            case .identityKeyStorage: identityStored
            case .x25519KnownAnswer: verifyX25519KnownAnswer()
            case .x25519Agreement: verifyX25519Agreement()
            case .invalidPeerKeyRejection: verifyInvalidPeerKeyRejection()
            case .hkdfKnownAnswer: verifyHKDFKnownAnswer()
            case .sessionKeySeparation: verifySessionKeySeparation()
            case .aesGCMRoundTrip: verifyAESGCMRoundTrip()
            case .tamperRejection: verifyTamperRejection()
            case .associatedDataBinding: verifyAssociatedDataBinding()
            }
            return SecurityCheck(kind: kind, passed: passed)
        }

        let report = SecurityReport(checks: checks)
        logger.log(.securityCheckCompleted(passed: report.passedCount, total: checks.count))
        return report
    }

    private func verifyIdentityKeyStorage() async -> Bool {
        guard (try? keychain.contains(.identityPrivateKey)) == true else { return false }
        return (try? await crypto.loadIdentity()) != nil
    }

    // RFC 7748 §6.1
    private func verifyX25519KnownAnswer() -> Bool {
        guard let alicePrivate = Data(hexString: "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"),
              let bobPrivate = Data(hexString: "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"),
              let alicePublic = Data(hexString: "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"),
              let bobPublic = Data(hexString: "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f"),
              let expected = Data(hexString: "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"),
              let alice = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: alicePrivate),
              let bob = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: bobPrivate),
              alice.publicKey.rawRepresentation == alicePublic,
              bob.publicKey.rawRepresentation == bobPublic,
              let aliceSecret = try? keyAgreement.sharedSecret(privateKey: alice, peerPublicKey: bob.publicKey),
              let bobSecret = try? keyAgreement.sharedSecret(privateKey: bob, peerPublicKey: alice.publicKey)
        else { return false }

        return bytes(of: aliceSecret) == expected && bytes(of: bobSecret) == expected
    }

    private func verifyX25519Agreement() -> Bool {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        guard let aliceKey = try? keyAgreement.deriveSessionKey(privateKey: alice, peerPublicKey: bob.publicKey),
              let bobKey = try? keyAgreement.deriveSessionKey(privateKey: bob, peerPublicKey: alice.publicKey)
        else { return false }

        return aliceKey.bitCount == 256 && bytes(of: aliceKey) == bytes(of: bobKey)
    }

    private func verifyInvalidPeerKeyRejection() -> Bool {
        let local = Curve25519.KeyAgreement.PrivateKey()
        guard let lowOrderPoint = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(count: 32)) else {
            return true
        }

        let rejectsLowOrder = (try? keyAgreement.deriveSessionKey(privateKey: local, peerPublicKey: lowOrderPoint)) == nil
        let rejectsOwnKey = (try? keyAgreement.deriveSessionKey(privateKey: local, peerPublicKey: local.publicKey)) == nil
        return rejectsLowOrder && rejectsOwnKey
    }

    // RFC 5869 Appendix A.1
    private func verifyHKDFKnownAnswer() -> Bool {
        guard let salt = Data(hexString: "000102030405060708090a0b0c"),
              let info = Data(hexString: "f0f1f2f3f4f5f6f7f8f9"),
              let expected = Data(hexString: "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")
        else { return false }

        let inputKeyMaterial = SymmetricKey(data: Data(repeating: 0x0b, count: 22))
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, info: info, outputByteCount: 42)
        return bytes(of: derived) == expected
    }

    private func verifySessionKeySeparation() -> Bool {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let carol = Curve25519.KeyAgreement.PrivateKey()
        guard let rawSecret = try? keyAgreement.sharedSecret(privateKey: alice, peerPublicKey: bob.publicKey),
              let withBob = try? keyAgreement.deriveSessionKey(privateKey: alice, peerPublicKey: bob.publicKey),
              let withCarol = try? keyAgreement.deriveSessionKey(privateKey: alice, peerPublicKey: carol.publicKey)
        else { return false }

        return bytes(of: withBob) != bytes(of: rawSecret) && bytes(of: withBob) != bytes(of: withCarol)
    }

    private func verifyAESGCMRoundTrip() -> Bool {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Ibanga security check".utf8)
        let associatedData = Data(UUID().uuidString.utf8)
        guard let first = try? encryption.seal(plaintext, using: key, authenticating: associatedData),
              let second = try? encryption.seal(plaintext, using: key, authenticating: associatedData),
              let reopened = try? SealedPayload(combined: first.combined),
              let decrypted = try? encryption.open(reopened, using: key, authenticating: associatedData)
        else { return false }

        return decrypted == plaintext
            && first.ciphertext != plaintext
            && first.nonce != second.nonce
    }

    private func verifyTamperRejection() -> Bool {
        let key = SymmetricKey(size: .bits256)
        let associatedData = Data("header".utf8)
        guard let payload = try? encryption.seal(Data("untouched".utf8), using: key, authenticating: associatedData) else {
            return false
        }

        let tamperedCiphertext = SealedPayload(nonce: payload.nonce, ciphertext: flippingFirstBit(of: payload.ciphertext), tag: payload.tag)
        let tamperedTag = SealedPayload(nonce: payload.nonce, ciphertext: payload.ciphertext, tag: flippingFirstBit(of: payload.tag))
        let tamperedNonce = SealedPayload(nonce: flippingFirstBit(of: payload.nonce), ciphertext: payload.ciphertext, tag: payload.tag)

        return [tamperedCiphertext, tamperedTag, tamperedNonce].allSatisfy { tampered in
            rejectsAsUnauthentic { () throws(CryptoError) in try encryption.open(tampered, using: key, authenticating: associatedData) }
        } && rejectsAsUnauthentic { () throws(CryptoError) in
            try encryption.open(payload, using: SymmetricKey(size: .bits256), authenticating: associatedData)
        }
    }

    private func verifyAssociatedDataBinding() -> Bool {
        let key = SymmetricKey(size: .bits256)
        guard let payload = try? encryption.seal(Data("bound".utf8), using: key, authenticating: Data("sender:alice".utf8)) else {
            return false
        }
        return rejectsAsUnauthentic { () throws(CryptoError) in
            try encryption.open(payload, using: key, authenticating: Data("sender:mallory".utf8))
        }
    }

    private func rejectsAsUnauthentic(_ operation: () throws(CryptoError) -> Data) -> Bool {
        do {
            _ = try operation()
            return false
        } catch {
            return error == .authenticationFailed
        }
    }

    private func flippingFirstBit(of data: Data) -> Data {
        var copy = Data(data)
        guard !copy.isEmpty else { return copy }
        copy[copy.startIndex] ^= 0x01
        return copy
    }

    private func bytes(of material: some ContiguousBytes) -> Data {
        material.withUnsafeBytes { Data($0) }
    }
}
