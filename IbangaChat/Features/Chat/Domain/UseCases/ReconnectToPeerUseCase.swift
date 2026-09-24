import Foundation

struct ReconnectToPeerUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ peerID: Peer.ID) async throws(SessionError) {
        let handshake = try await sessions.reconnect(to: peerID)
        guard chat.registerPeer(handshake) != nil else { throw .identityMismatch }
    }
}
