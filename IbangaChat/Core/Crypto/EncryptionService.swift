import CryptoKit
import Foundation

nonisolated struct SealedPayload: Codable, Hashable, Sendable {
    static let nonceByteCount = 12
    static let tagByteCount = 16

    let nonce: Data
    let ciphertext: Data
    let tag: Data

    var combined: Data { nonce + ciphertext + tag }

    init(nonce: Data, ciphertext: Data, tag: Data) {
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }

    init(combined: Data) throws(CryptoError) {
        guard combined.count >= Self.nonceByteCount + Self.tagByteCount else { throw .malformedPayload }
        let bytes = Data(combined)
        nonce = bytes.prefix(Self.nonceByteCount)
        tag = bytes.suffix(Self.tagByteCount)
        ciphertext = bytes.dropFirst(Self.nonceByteCount).dropLast(Self.tagByteCount)
    }
}

nonisolated protocol EncryptionServiceProtocol: Sendable {
    func seal(
        _ plaintext: Data,
        using key: SymmetricKey,
        authenticating associatedData: Data
    ) throws(CryptoError) -> SealedPayload

    func open(
        _ payload: SealedPayload,
        using key: SymmetricKey,
        authenticating associatedData: Data
    ) throws(CryptoError) -> Data
}

nonisolated struct EncryptionService: EncryptionServiceProtocol {
    private static let requiredKeyBitCount = 256

    func seal(
        _ plaintext: Data,
        using key: SymmetricKey,
        authenticating associatedData: Data
    ) throws(CryptoError) -> SealedPayload {
        guard key.bitCount == Self.requiredKeyBitCount else { throw .invalidKeyMaterial }
        do {
            let box = try AES.GCM.seal(plaintext, using: key, authenticating: associatedData)
            return SealedPayload(nonce: Data(box.nonce), ciphertext: box.ciphertext, tag: box.tag)
        } catch {
            throw .encryptionFailed
        }
    }

    func open(
        _ payload: SealedPayload,
        using key: SymmetricKey,
        authenticating associatedData: Data
    ) throws(CryptoError) -> Data {
        guard key.bitCount == Self.requiredKeyBitCount else { throw .invalidKeyMaterial }
        guard payload.nonce.count == SealedPayload.nonceByteCount,
              payload.tag.count == SealedPayload.tagByteCount
        else { throw .malformedPayload }

        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: payload.nonce),
                ciphertext: payload.ciphertext,
                tag: payload.tag
            )
        } catch {
            throw .malformedPayload
        }

        do {
            return try AES.GCM.open(box, using: key, authenticating: associatedData)
        } catch {
            throw .authenticationFailed
        }
    }
}
