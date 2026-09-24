import Foundation
import Observation

@Observable
final class SessionRepository: SessionRepositoryProtocol {
    private static let displayNameKey = "ibanga.profile.displayName"
    private static let handshakeTimeout: Duration = .seconds(12)
    private static let maximumServiceNameBytes = 63

    private(set) var localDisplayName: String
    private(set) var nearbyDevices: [NearbyDevice] = []
    private var peerStates: [Peer.ID: SecureConnectionState] = [:]
    private var incomingTransfers: [Peer.ID: Double] = [:]

    let events: AsyncStream<SessionEvent>

    @ObservationIgnored private let eventContinuation: AsyncStream<SessionEvent>.Continuation
    @ObservationIgnored private let network: any NetworkServiceProtocol
    @ObservationIgnored private let crypto: any CryptoServiceProtocol
    @ObservationIgnored private let logger: SecureLogger

    @ObservationIgnored private var localIdentity: DeviceIdentity?
    @ObservationIgnored private var channels: [ConnectionID: Channel] = [:]
    @ObservationIgnored private var securePeers: [Peer.ID: ConnectionID] = [:]
    @ObservationIgnored private var pendingConnects: [ConnectionID: CheckedContinuation<Result<PeerHandshake, SessionError>, Never>] = [:]
    @ObservationIgnored private var networkTask: Task<Void, Never>?
    @ObservationIgnored private var knownPeers: Set<Peer.ID> = []
    @ObservationIgnored private var autoConnecting: Set<Peer.ID> = []

    init(
        network: any NetworkServiceProtocol,
        crypto: any CryptoServiceProtocol,
        defaultDisplayName: String,
        logger: SecureLogger
    ) {
        self.network = network
        self.crypto = crypto
        self.logger = logger
        self.localDisplayName = Self.sanitizedDisplayName(UserDefaults.standard.string(forKey: Self.displayNameKey) ?? "")
            ?? Self.sanitizedDisplayName(defaultDisplayName)
            ?? "iPhone"
        (events, eventContinuation) = AsyncStream.makeStream(of: SessionEvent.self)
    }

    var secureConnectionCount: Int {
        peerStates.values.count { $0 == .secure }
    }

    func connectionState(for peerID: Peer.ID) -> SecureConnectionState {
        peerStates[peerID] ?? .inactive
    }

    func incomingTransferProgress(from peerID: Peer.ID) -> Double? {
        incomingTransfers[peerID]
    }

    // MARK: Lifecycle

    func start(localIdentity identity: DeviceIdentity) async {
        guard localIdentity == nil else { return }
        localIdentity = identity

        networkTask = Task { [weak self, network] in
            for await event in network.events {
                await self?.handle(event)
            }
        }
        await network.start(advertisingAs: localDisplayName, fingerprint: identity.fingerprint)
    }

    func rememberPeers(_ peerIDs: [Peer.ID]) {
        knownPeers.formUnion(peerIDs)
        reconnectKnownPeers()
    }

    func updateLocalDisplayName(_ name: String) async {
        guard let sanitized = Self.sanitizedDisplayName(name), sanitized != localDisplayName else { return }
        localDisplayName = sanitized
        UserDefaults.standard.set(sanitized, forKey: Self.displayNameKey)

        if let localIdentity {
            await network.start(advertisingAs: sanitized, fingerprint: localIdentity.fingerprint)
        }
    }

    // MARK: Connecting

    func connect(to device: NearbyDevice) async throws(SessionError) -> PeerHandshake {
        if let peerID = device.claimedPeerID, let existing = secureHandshake(for: peerID) {
            return existing
        }

        let channel = Channel(id: ConnectionID(), direction: .outbound, expectedPeerID: device.claimedPeerID)
        channels[channel.id] = channel
        if let peerID = device.claimedPeerID {
            peerStates[peerID] = .connecting
        }

        let result = await withCheckedContinuation { continuation in
            pendingConnects[channel.id] = continuation
            Task { await open(channel, serviceID: device.id) }
        }
        return try result.get()
    }

    func reconnect(to peerID: Peer.ID) async throws(SessionError) -> PeerHandshake {
        if let existing = secureHandshake(for: peerID) {
            return existing
        }
        guard let device = nearbyDevices.first(where: { $0.claimedPeerID == peerID }) else {
            throw .peerUnavailable
        }
        return try await connect(to: device)
    }

    func disconnect(from peerID: Peer.ID) async {
        guard let id = securePeers[peerID] else { return }
        await network.disconnect(id)
    }

    // MARK: Sending

    func send(
        _ payload: SessionPayload,
        messageID: UUID,
        sentAt: Date,
        to peerID: Peer.ID,
        progress: ((Double) -> Void)?
    ) async throws(SessionError) {
        guard let id = securePeers[peerID], let channel = channels[id] else { throw .notConnected }

        // Serialise per channel so fragments and sequence numbers reach the peer in order.
        let previous = channel.sendTail
        let operation = Task { () -> SessionError? in
            await previous?.value
            do throws(SessionError) {
                try await transmitMessage(payload, messageID: messageID, sentAt: sentAt, on: channel, progress: progress)
                return nil
            } catch {
                return error
            }
        }
        channel.sendTail = Task { _ = await operation.value }

        if let error = await operation.value { throw error }
    }

    func verificationCode(for peer: Peer) async -> String? {
        try? await crypto.verificationCode(peerIdentityKey: peer.identityKey)
    }

    // MARK: Network events

    private func handle(_ event: NetworkEvent) async {
        switch event {
        case .servicesChanged(let services):
            nearbyDevices = services.map { NearbyDevice(id: $0.id, name: $0.name, claimedPeerID: $0.fingerprint) }
            reconnectKnownPeers()
        case let .connectionReady(id, direction):
            await beginHandshake(on: id, direction: direction)
        case let .packetReceived(id, packet):
            await process(packet, on: id)
        case .connectionClosed(let id):
            connectionClosed(id)
        }
    }

    private func open(_ channel: Channel, serviceID: String) async {
        do {
            try await network.connect(to: serviceID, id: channel.id)
            scheduleTimeout(for: channel)
        } catch {
            fail(channel, .peerUnavailable)
            channels[channel.id] = nil
        }
    }

    private func beginHandshake(on id: ConnectionID, direction: ConnectionDirection) async {
        let channel: Channel
        if let existing = channels[id] {
            channel = existing
        } else {
            channel = Channel(id: id, direction: direction, expectedPeerID: nil)
            channels[id] = channel
            scheduleTimeout(for: channel)
        }

        if let peerID = channel.expectedPeerID, peerStates[peerID] != .secure {
            peerStates[peerID] = .establishingSession
        }

        do {
            let pending = try await crypto.beginHandshake()
            channel.pending = pending
            let hello = HandshakeHello(
                version: WireProtocol.version,
                identityKey: pending.offer.identityKey,
                ephemeralKey: pending.offer.ephemeralKey,
                displayName: localDisplayName
            )
            try await transmit(.handshake, WireProtocol.encode(hello), on: channel)
        } catch {
            fail(channel, .handshakeFailed)
        }
    }

    private func process(_ packet: NetworkPacket, on id: ConnectionID) async {
        guard let channel = channels[id], channel.failure == nil else { return }

        switch packet.kind {
        case .handshake:
            await receiveHello(packet.payload, on: channel)
        case .keyConfirmation:
            await receiveConfirmation(packet.payload, on: channel)
        case .message:
            await receiveMessage(packet.payload, on: channel)
        }
    }

    private func receiveHello(_ payload: Data, on channel: Channel) async {
        guard let pending = channel.pending, channel.session == nil else {
            return fail(channel, .protocolViolation)
        }

        do {
            let hello = try WireProtocol.decode(HandshakeHello.self, from: payload)
            guard hello.version == WireProtocol.version else {
                return fail(channel, .incompatibleVersion)
            }

            let session = try await crypto.completeHandshake(
                pending,
                peerOffer: HandshakeOffer(identityKey: hello.identityKey, ephemeralKey: hello.ephemeralKey)
            )
            if let expected = channel.expectedPeerID, expected != session.peerFingerprint {
                return fail(channel, .identityMismatch)
            }

            channel.pending = nil
            channel.session = session
            channel.peer = PeerHandshake(
                peerID: session.peerFingerprint,
                identityKey: hello.identityKey,
                displayName: Self.sanitizedDisplayName(hello.displayName) ?? "Nearby device"
            )
            if peerStates[session.peerFingerprint] != .secure {
                peerStates[session.peerFingerprint] = .establishingSession
            }

            let tag = await crypto.confirmationTag(for: session)
            try await transmit(.keyConfirmation, WireProtocol.encode(KeyConfirmation(tag: tag)), on: channel)
        } catch {
            fail(channel, .handshakeFailed)
        }
    }

    private func receiveConfirmation(_ payload: Data, on channel: Channel) async {
        guard let session = channel.session, let peer = channel.peer, !channel.isAuthenticated else {
            return fail(channel, .protocolViolation)
        }

        do {
            let confirmation = try WireProtocol.decode(KeyConfirmation.self, from: payload)
            try await crypto.verifyPeerConfirmation(confirmation.tag, for: session)
        } catch {
            return fail(channel, .handshakeFailed)
        }

        channel.isAuthenticated = true
        promote(channel, peer: peer)
    }

    private func receiveMessage(_ payload: Data, on channel: Channel) async {
        guard channel.isAuthenticated, let session = channel.session, let peer = channel.peer else {
            return fail(channel, .protocolViolation)
        }
        guard let envelope = try? WireProtocol.decode(EncryptedMessage.self, from: payload) else {
            return fail(channel, .protocolViolation)
        }
        guard envelope.sequence > channel.lastReceivedSequence else {
            logger.log(.failure(.session, code: "replay-rejected"))
            return
        }

        let plaintext: Data
        do {
            plaintext = try await crypto.open(envelope.payload, in: session, associatedData: envelope.associatedData)
        } catch {
            return fail(channel, .messageRejected)
        }
        channel.lastReceivedSequence = envelope.sequence

        guard let fragment = try? WireProtocol.decode(PayloadFragment.self, from: plaintext) else {
            return fail(channel, .protocolViolation)
        }
        let assembled: Data?
        do throws(SessionError) {
            assembled = try reassemble(fragment, of: envelope, on: channel, from: peer.peerID)
        } catch {
            return fail(channel, error)
        }
        guard let assembled else { return }

        guard let content = try? WireProtocol.decode(SessionPayload.self, from: assembled) else {
            return fail(channel, .protocolViolation)
        }

        logger.log(.encryptedMessageReceived)
        eventContinuation.yield(.received(IncomingEnvelope(
            peerID: peer.peerID,
            messageID: envelope.id,
            sentAt: envelope.sentAt,
            payload: content
        )))
    }

    /// Assembles fragments in order. Returns the full payload once the last fragment arrives.
    /// Fragments of different messages never interleave because sending is serialised per channel.
    private func reassemble(
        _ fragment: PayloadFragment,
        of envelope: EncryptedMessage,
        on channel: Channel,
        from peerID: Peer.ID
    ) throws(SessionError) -> Data? {
        guard fragment.count >= 1,
              fragment.count <= WireProtocol.maximumFragmentCount,
              fragment.index < fragment.count,
              fragment.totalByteCount <= WireProtocol.maximumPayloadByteCount
        else { throw .protocolViolation }

        var transfer: InboundTransfer
        if fragment.index == 0 {
            guard channel.inbound == nil else { throw .protocolViolation }
            transfer = InboundTransfer(messageID: envelope.id, count: fragment.count, totalByteCount: fragment.totalByteCount)
        } else {
            guard let existing = channel.inbound,
                  existing.messageID == envelope.id,
                  existing.nextIndex == fragment.index,
                  existing.count == fragment.count,
                  existing.totalByteCount == fragment.totalByteCount
            else { throw .protocolViolation }
            transfer = existing
        }

        transfer.data.append(fragment.bytes)
        transfer.nextIndex += 1
        guard transfer.data.count <= transfer.totalByteCount else { throw .protocolViolation }

        guard transfer.nextIndex == transfer.count else {
            channel.inbound = transfer
            incomingTransfers[peerID] = Double(transfer.nextIndex) / Double(transfer.count)
            return nil
        }

        channel.inbound = nil
        incomingTransfers[peerID] = nil
        guard transfer.data.count == transfer.totalByteCount else { throw .protocolViolation }
        return transfer.data
    }

    private func transmitMessage(
        _ payload: SessionPayload,
        messageID: UUID,
        sentAt: Date,
        on channel: Channel,
        progress: ((Double) -> Void)?
    ) async throws(SessionError) {
        guard channel.isAuthenticated, channel.failure == nil, let session = channel.session else {
            throw .notConnected
        }

        let encoded: Data
        do {
            encoded = try WireProtocol.encode(payload)
        } catch {
            throw .encryptionFailed
        }
        guard encoded.count <= WireProtocol.maximumPayloadByteCount else { throw .transmissionFailed }

        let milliseconds = sentAt.millisecondsSince1970
        let fragmentCount = max(1, (encoded.count + WireProtocol.fragmentByteCount - 1) / WireProtocol.fragmentByteCount)

        for index in 0..<fragmentCount {
            guard channel.failure == nil else { throw .notConnected }

            let start = encoded.startIndex + index * WireProtocol.fragmentByteCount
            let end = min(start + WireProtocol.fragmentByteCount, encoded.endIndex)
            let fragment = PayloadFragment(
                index: index,
                count: fragmentCount,
                totalByteCount: encoded.count,
                bytes: encoded.subdata(in: start..<end)
            )

            let sequence = channel.nextSendSequence
            channel.nextSendSequence += 1
            let associatedData = EncryptedMessage.associatedData(id: messageID, sequence: sequence, sentAtMilliseconds: milliseconds)

            let sealed: SealedPayload
            do {
                sealed = try await crypto.seal(WireProtocol.encode(fragment), in: session, associatedData: associatedData)
            } catch {
                throw .encryptionFailed
            }

            let envelope = EncryptedMessage(id: messageID, sequence: sequence, sentAtMilliseconds: milliseconds, payload: sealed)
            do {
                try await transmit(.message, WireProtocol.encode(envelope), on: channel)
            } catch {
                throw .transmissionFailed
            }
            progress?(Double(index + 1) / Double(fragmentCount))
        }
        logger.log(.encryptedMessageSent)
    }

    private func transmit(_ kind: NetworkPacket.Kind, _ payload: Data, on channel: Channel) async throws(NetworkError) {
        try await network.send(NetworkPacket(kind: kind, payload: payload), on: channel.id)
    }

    // MARK: Session state

    private func promote(_ channel: Channel, peer: PeerHandshake) {
        if let existingID = securePeers[peer.peerID], existingID != channel.id, let existing = channels[existingID] {
            // Both devices dialled each other. Each side applies the same rule, so both keep the same connection.
            if keeps(existing, over: channel, peerID: peer.peerID) {
                resumeConnect(channel.id, with: .success(peer))
                Task { await network.disconnect(channel.id) }
                return
            }
            Task { await network.disconnect(existingID) }
        }

        securePeers[peer.peerID] = channel.id
        peerStates[peer.peerID] = .secure
        knownPeers.insert(peer.peerID)
        logger.log(.peerConnected)
        eventContinuation.yield(.established(peer))
        resumeConnect(channel.id, with: .success(peer))
    }

    private func keeps(_ existing: Channel, over candidate: Channel, peerID: Peer.ID) -> Bool {
        guard let localPeerID = localIdentity?.fingerprint else { return true }
        let localIsLower = localPeerID < peerID
        let initiatedByLower = { (channel: Channel) in (channel.direction == .outbound) == localIsLower }
        return initiatedByLower(existing) || !initiatedByLower(candidate)
    }

    private func fail(_ channel: Channel, _ error: SessionError) {
        guard channel.failure == nil else { return }
        channel.failure = error
        logger.log(.failure(.session, code: error.logCode))

        if let peerID = channel.peer?.peerID ?? channel.expectedPeerID {
            if securePeers[peerID] == channel.id {
                securePeers[peerID] = nil
                peerStates[peerID] = .failed
            } else if securePeers[peerID] == nil {
                peerStates[peerID] = .failed
            }
        }

        resumeConnect(channel.id, with: .failure(error))
        Task { await network.disconnect(channel.id) }
    }

    private func connectionClosed(_ id: ConnectionID) {
        guard let channel = channels.removeValue(forKey: id) else { return }
        resumeConnect(id, with: .failure(channel.failure ?? .connectionFailed))

        guard let peerID = channel.peer?.peerID ?? channel.expectedPeerID else { return }
        if channel.inbound != nil {
            incomingTransfers[peerID] = nil
        }
        if securePeers[peerID] == id {
            securePeers[peerID] = nil
            peerStates[peerID] = nil
            logger.log(.peerDisconnected)
        } else if securePeers[peerID] == nil, channel.failure == nil {
            peerStates[peerID] = nil
        }
    }

    /// Re-establishes sessions with previously connected peers as soon as they are nearby.
    /// Only the peer with the lower fingerprint dials, so the two devices never race each other.
    /// A failed session is not retried automatically; the user decides.
    private func reconnectKnownPeers() {
        guard let localPeerID = localIdentity?.fingerprint else { return }

        for device in nearbyDevices {
            guard let peerID = device.claimedPeerID,
                  knownPeers.contains(peerID),
                  localPeerID < peerID,
                  connectionState(for: peerID) == .inactive,
                  !autoConnecting.contains(peerID)
            else { continue }

            autoConnecting.insert(peerID)
            Task {
                _ = try? await connect(to: device)
                autoConnecting.remove(peerID)
            }
        }
    }

    private func scheduleTimeout(for channel: Channel) {
        Task { [weak self, weak channel] in
            try? await Task.sleep(for: Self.handshakeTimeout)
            guard let self, let channel, !channel.isAuthenticated else { return }
            fail(channel, .timedOut)
        }
    }

    private func resumeConnect(_ id: ConnectionID, with result: Result<PeerHandshake, SessionError>) {
        pendingConnects.removeValue(forKey: id)?.resume(returning: result)
    }

    private func secureHandshake(for peerID: Peer.ID) -> PeerHandshake? {
        securePeers[peerID].flatMap { channels[$0]?.peer }
    }

    static func sanitizedDisplayName(_ name: String) -> String? {
        var sanitized = String(
            name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        sanitized = String(sanitized.prefix(WireProtocol.maximumDisplayNameLength))
        while sanitized.utf8.count > maximumServiceNameBytes {
            sanitized.removeLast()
        }
        return sanitized.isEmpty ? nil : sanitized
    }
}

private final class Channel {
    let id: ConnectionID
    let direction: ConnectionDirection
    let expectedPeerID: Peer.ID?

    var pending: PendingHandshake?
    var session: SecureSession?
    var peer: PeerHandshake?
    var isAuthenticated = false
    var failure: SessionError?
    var nextSendSequence: UInt64 = 1
    var lastReceivedSequence: UInt64 = 0
    var sendTail: Task<Void, Never>?
    var inbound: InboundTransfer?

    init(id: ConnectionID, direction: ConnectionDirection, expectedPeerID: Peer.ID?) {
        self.id = id
        self.direction = direction
        self.expectedPeerID = expectedPeerID
    }
}

private struct InboundTransfer {
    let messageID: UUID
    let count: Int
    let totalByteCount: Int
    var nextIndex = 0
    var data = Data()
}
