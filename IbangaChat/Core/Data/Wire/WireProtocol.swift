import Foundation

nonisolated enum WireProtocol {
    static let version = 1
    static let maximumDisplayNameLength = 40

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ value: some Encodable) throws -> Data {
        try encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        try decoder.decode(type, from: data)
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

nonisolated struct EncryptedMessage: Codable, Sendable {
    let id: UUID
    let sequence: UInt64
    let sentAtMilliseconds: Int64
    let payload: SealedPayload

    var sentAt: Date { Date(timeIntervalSince1970: TimeInterval(sentAtMilliseconds) / 1000) }

    static func associatedData(id: UUID, sequence: UInt64, sentAtMilliseconds: Int64) -> Data {
        var data = Data("IbangaChat/v1/message".utf8)
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
