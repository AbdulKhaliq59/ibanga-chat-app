import Foundation

nonisolated enum SessionEvent: Sendable {
    case established(PeerHandshake)
    case received(IncomingEnvelope)
}

protocol SessionRepositoryProtocol: AnyObject {
    var localDisplayName: String { get }
    var nearbyDevices: [NearbyDevice] { get }
    var secureConnectionCount: Int { get }
    var events: AsyncStream<SessionEvent> { get }

    func start(localIdentity: DeviceIdentity) async
    /// Peers to reconnect to automatically when they are discovered nearby.
    func rememberPeers(_ peerIDs: [Peer.ID])
    func updateLocalDisplayName(_ name: String) async
    func connectionState(for peerID: Peer.ID) -> SecureConnectionState
    /// Fraction of a multi-fragment payload received so far, or `nil` when nothing is in flight.
    func incomingTransferProgress(from peerID: Peer.ID) -> Double?

    /// Returns once the session is authenticated. Never returns an unauthenticated connection.
    func connect(to device: NearbyDevice) async throws(SessionError) -> PeerHandshake
    func reconnect(to peerID: Peer.ID) async throws(SessionError) -> PeerHandshake
    func disconnect(from peerID: Peer.ID) async

    /// Encrypts and transmits. Throws `.notConnected` rather than ever sending insecurely.
    func send(
        _ payload: SessionPayload,
        messageID: UUID,
        sentAt: Date,
        to peerID: Peer.ID,
        progress: ((Double) -> Void)?
    ) async throws(SessionError)
    func verificationCode(for peer: Peer) async -> String?
}

extension SessionRepositoryProtocol {
    func send(_ payload: SessionPayload, messageID: UUID, sentAt: Date, to peerID: Peer.ID) async throws(SessionError) {
        try await send(payload, messageID: messageID, sentAt: sentAt, to: peerID, progress: nil)
    }
}
