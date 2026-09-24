import Foundation
import Network

nonisolated struct ConnectionID: Hashable, Sendable, CustomStringConvertible {
    let rawValue = UUID()

    var description: String { rawValue.uuidString }
}

nonisolated enum ConnectionDirection: Sendable {
    case inbound
    case outbound
}

nonisolated final class NetworkConnection: @unchecked Sendable {
    enum Event: Sendable {
        case ready
        case packet(NetworkPacket)
        case closed
    }

    let id: ConnectionID
    let direction: ConnectionDirection

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let onEvent: @Sendable (Event) -> Void
    private var isClosed = false

    init(
        id: ConnectionID,
        connection: NWConnection,
        direction: ConnectionDirection,
        onEvent: @escaping @Sendable (Event) -> Void
    ) {
        self.id = id
        self.connection = connection
        self.direction = direction
        self.onEvent = onEvent
        self.queue = DispatchQueue(label: "ibanga.connection.\(id)")
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        connection.start(queue: queue)
    }

    func send(_ packet: NetworkPacket) async throws(NetworkError) {
        let data = try packet.framed()
        let failure: NetworkError? = await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                continuation.resume(returning: error == nil ? nil : .sendFailed)
            })
        }
        if let failure { throw failure }
    }

    func cancel() {
        queue.async { [self] in close() }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            onEvent(.ready)
            receiveHeader()
        case .waiting:
            // The peer is unreachable; fail fast instead of waiting indefinitely.
            close()
        case .failed, .cancelled:
            close()
        default:
            break
        }
    }

    private func receiveHeader() {
        connection.receive(
            minimumIncompleteLength: NetworkPacket.headerByteCount,
            maximumLength: NetworkPacket.headerByteCount
        ) { [weak self] data, _, _, error in
            guard let self, !isClosed else { return }
            guard error == nil, let data, data.count == NetworkPacket.headerByteCount else { return close() }

            do {
                let header = try NetworkPacket.parseHeader(data)
                if header.payloadLength == 0 {
                    onEvent(.packet(NetworkPacket(kind: header.kind, payload: Data())))
                    receiveHeader()
                } else {
                    receivePayload(kind: header.kind, length: header.payloadLength)
                }
            } catch {
                close()
            }
        }
    }

    private func receivePayload(kind: NetworkPacket.Kind, length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self, !isClosed else { return }
            guard error == nil, let data, data.count == length else { return close() }

            onEvent(.packet(NetworkPacket(kind: kind, payload: data)))
            receiveHeader()
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.stateUpdateHandler = nil
        connection.cancel()
        onEvent(.closed)
    }
}
