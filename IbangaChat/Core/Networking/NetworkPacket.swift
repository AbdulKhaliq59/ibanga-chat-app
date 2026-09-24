import Foundation

nonisolated struct NetworkPacket: Equatable, Sendable {
    enum Kind: UInt8, Sendable {
        case handshake = 1
        case keyConfirmation = 2
        case message = 3
    }

    static let headerByteCount = 5
    static let maximumPayloadByteCount = 8 * 1024 * 1024

    let kind: Kind
    let payload: Data

    func framed() throws(NetworkError) -> Data {
        guard payload.count <= Self.maximumPayloadByteCount else { throw .packetTooLarge }

        var data = Data(capacity: Self.headerByteCount + payload.count)
        data.append(kind.rawValue)
        withUnsafeBytes(of: UInt32(payload.count).bigEndian) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }

    static func parseHeader(_ header: Data) throws(NetworkError) -> (kind: Kind, payloadLength: Int) {
        let bytes = [UInt8](header)
        guard bytes.count == headerByteCount, let kind = Kind(rawValue: bytes[0]) else { throw .malformedPacket }

        let length = bytes[1...4].reduce(0) { $0 << 8 | Int($1) }
        guard length <= maximumPayloadByteCount else { throw .packetTooLarge }
        return (kind, length)
    }
}
