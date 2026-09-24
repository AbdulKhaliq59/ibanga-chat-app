import Foundation

nonisolated enum WireProtocol {
    static let version = 2
    static let maximumDisplayNameLength = 40
    /// Payloads larger than this are split into individually sealed fragments.
    static let fragmentByteCount = 256 * 1024
    static let maximumPayloadByteCount = Attachment.maximumByteCount + 64 * 1024
    static let maximumFragmentCount = maximumPayloadByteCount / fragmentByteCount + 1

    static func encode(_ value: some Encodable) throws -> Data {
        // Binary property lists carry `Data` as raw bytes rather than base64.
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        try PropertyListDecoder().decode(type, from: data)
    }
}

/// First packet on every connection. Contains only public key material.
nonisolated struct HandshakeHello: Codable, Sendable {
    let version: Int
    let identityKey: Data
    let ephemeralKey: Data
    let displayName: String
}

/// Proves the sender derived the same session keys, and therefore holds its identity private key.
nonisolated struct KeyConfirmation: Codable, Sendable {
    let tag: Data
}

/// The plaintext inside every `EncryptedMessage`: one slice of an encoded `SessionPayload`.
/// Small payloads are a single fragment; attachments span many, each sealed and sequenced separately.
nonisolated struct PayloadFragment: Codable, Sendable {
    let index: Int
    let count: Int
    let totalByteCount: Int
    let bytes: Data
}

nonisolated struct EncryptedMessage: Codable, Sendable {
    let id: UUID
    let sequence: UInt64
    let sentAtMilliseconds: Int64
    let payload: SealedPayload

    var sentAt: Date { Date(timeIntervalSince1970: TimeInterval(sentAtMilliseconds) / 1000) }

    static func associatedData(id: UUID, sequence: UInt64, sentAtMilliseconds: Int64) -> Data {
        var data = Data("IbangaChat/v2/message".utf8)
        withUnsafeBytes(of: id.uuid) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sequence.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sentAtMilliseconds.bigEndian) { data.append(contentsOf: $0) }
        return data
    }

    var associatedData: Data {
        Self.associatedData(id: id, sequence: sequence, sentAtMilliseconds: sentAtMilliseconds)
    }
}

nonisolated extension Date {
    var millisecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded(.down)) }
}
