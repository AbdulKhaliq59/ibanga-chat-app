import Foundation
import Network

nonisolated struct DiscoveredService: Hashable, Sendable {
    let id: String
    let name: String
    let fingerprint: String?
}

nonisolated enum NetworkEvent: Sendable {
    case servicesChanged([DiscoveredService])
    case connectionReady(ConnectionID, ConnectionDirection)
    case packetReceived(ConnectionID, NetworkPacket)
    case connectionClosed(ConnectionID)
}

nonisolated protocol NetworkServiceProtocol: Sendable {
    var events: AsyncStream<NetworkEvent> { get }

    func start(advertisingAs name: String, fingerprint: String) async
    func stop() async
    func connect(to serviceID: String, id: ConnectionID) async throws(NetworkError)
    func send(_ packet: NetworkPacket, on id: ConnectionID) async throws(NetworkError)
    func disconnect(_ id: ConnectionID) async
}

/// Local-network discovery (Bonjour) and TCP transport built on Network.framework.
/// Responsible only for moving opaque packets; it never decrypts or interprets them.
actor NetworkService: NetworkServiceProtocol {
    static let serviceType = "_ibanga._tcp"
    private static let fingerprintKey = "fp"

    nonisolated let events: AsyncStream<NetworkEvent>
    private nonisolated let continuation: AsyncStream<NetworkEvent>.Continuation

    private let queue = DispatchQueue(label: "ibanga.network")
    private let logger: SecureLogger

    private var advertisement: (name: String, fingerprint: String)?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var endpoints: [String: NWEndpoint] = [:]
    private var connections: [ConnectionID: NetworkConnection] = [:]

    init(logger: SecureLogger) {
        self.logger = logger
        (events, continuation) = AsyncStream.makeStream(of: NetworkEvent.self)
    }

    func start(advertisingAs name: String, fingerprint: String) {
        advertisement = (name, fingerprint)
        startListener()
        startBrowser()
    }

    func stop() {
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        connections.values.forEach { $0.cancel() }
    }

    func connect(to serviceID: String, id: ConnectionID) throws(NetworkError) {
        guard let endpoint = endpoints[serviceID] else { throw .deviceUnavailable }
        register(NWConnection(to: endpoint, using: Self.parameters()), id: id, direction: .outbound)
    }

    func send(_ packet: NetworkPacket, on id: ConnectionID) async throws(NetworkError) {
        guard let connection = connections[id] else { throw .connectionUnavailable }
        do {
            try await connection.send(packet)
        } catch {
            logger.log(.failure(.network, code: error.logCode))
            throw error
        }
    }

    func disconnect(_ id: ConnectionID) {
        connections[id]?.cancel()
    }

    // MARK: Listener

    private func startListener() {
        listener?.cancel()
        guard let advertisement else { return }

        do {
            let listener = try NWListener(using: Self.parameters())
            var txtRecord = NWTXTRecord()
            txtRecord[Self.fingerprintKey] = advertisement.fingerprint
            listener.service = NWListener.Service(
                name: advertisement.name,
                type: Self.serviceType,
                domain: nil,
                txtRecord: txtRecord
            )
            listener.newConnectionHandler = { @Sendable [weak self] connection in
                Task { await self?.register(connection, id: ConnectionID(), direction: .inbound) }
            }
            listener.stateUpdateHandler = { @Sendable [weak self] state in
                Task { await self?.listenerStateChanged(state) }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            logger.log(.failure(.network, code: "listener-unavailable"))
        }
    }

    private func listenerStateChanged(_ state: NWListener.State) async {
        switch state {
        case .ready:
            logger.log(.networkReady)
        case .failed:
            logger.log(.failure(.network, code: "listener-failed"))
            try? await Task.sleep(for: .seconds(2))
            startListener()
        default:
            break
        }
    }

    // MARK: Browser

    private func startBrowser() {
        browser?.cancel()

        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil), using: Self.parameters())
        browser.browseResultsChangedHandler = { @Sendable [weak self] results, _ in
            Task { await self?.updateServices(from: results) }
        }
        browser.stateUpdateHandler = { @Sendable [weak self] state in
            if case .failed = state {
                Task { await self?.restartBrowser() }
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func restartBrowser() async {
        logger.log(.failure(.network, code: "browser-failed"))
        try? await Task.sleep(for: .seconds(2))
        startBrowser()
    }

    private func updateServices(from results: Set<NWBrowser.Result>) {
        var discovered: [String: DiscoveredService] = [:]
        var resolved: [String: NWEndpoint] = [:]

        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }

            var fingerprint: String?
            if case let .bonjour(txtRecord) = result.metadata {
                fingerprint = txtRecord[Self.fingerprintKey]
            }
            guard fingerprint != advertisement?.fingerprint, discovered[name] == nil else { continue }

            discovered[name] = DiscoveredService(id: name, name: name, fingerprint: fingerprint)
            resolved[name] = result.endpoint
        }

        endpoints = resolved
        continuation.yield(.servicesChanged(discovered.values.sorted { $0.name < $1.name }))
    }

    // MARK: Connections

    private func register(_ nwConnection: NWConnection, id: ConnectionID, direction: ConnectionDirection) {
        let continuation = continuation
        let connection = NetworkConnection(id: id, connection: nwConnection, direction: direction) { @Sendable [weak self] event in
            switch event {
            case .ready:
                continuation.yield(.connectionReady(id, direction))
            case .packet(let packet):
                continuation.yield(.packetReceived(id, packet))
            case .closed:
                continuation.yield(.connectionClosed(id))
                Task { await self?.remove(id) }
            }
        }
        connections[id] = connection
        connection.start()
    }

    private func remove(_ id: ConnectionID) {
        connections[id] = nil
    }

    private static func parameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        if let tcp = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 10
        }
        return parameters
    }
}
