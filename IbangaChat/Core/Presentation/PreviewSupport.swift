#if DEBUG
import Foundation

nonisolated struct PreviewIdentityRepository: IdentityRepositoryProtocol {
    static let identity = DeviceIdentity(
        publicKey: Data(repeating: 0xA5, count: 32),
        fingerprint: "47a231d1b6b201a8d05057e52d719e34"
    )

    func currentIdentity() async throws -> DeviceIdentity? { Self.identity }
    func createIdentity() async throws -> DeviceIdentity { Self.identity }
}

final class PreviewSessionRepository: SessionRepositoryProtocol {
    let localDisplayName = "iPhone"
    let nearbyDevices: [NearbyDevice] = []
    let secureConnectionCount = 1
    let events = AsyncStream<SessionEvent> { $0.finish() }

    func start(localIdentity: DeviceIdentity) async {}
    func rememberPeers(_ peerIDs: [Peer.ID]) {}
    func updateLocalDisplayName(_ name: String) async {}
    func connectionState(for peerID: Peer.ID) -> SecureConnectionState { .secure }
    func incomingTransferProgress(from peerID: Peer.ID) -> Double? { nil }
    func connect(to device: NearbyDevice) async throws(SessionError) -> PeerHandshake { throw .peerUnavailable }
    func reconnect(to peerID: Peer.ID) async throws(SessionError) -> PeerHandshake { throw .peerUnavailable }
    func disconnect(from peerID: Peer.ID) async {}
    func send(
        _ payload: SessionPayload,
        messageID: UUID,
        sentAt: Date,
        to peerID: Peer.ID,
        progress: ((Double) -> Void)?
    ) async throws(SessionError) {}
    func verificationCode(for peer: Peer) async -> String? { "481 927 315 062" }
}
#endif
