import Foundation

struct ConnectToPeerUseCase {
    let chat: any ChatRepositoryProtocol
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ device: NearbyDevice) async throws(SessionError) -> Conversation {
        let handshake = try await sessions.connect(to: device)
        guard let conversation = chat.registerPeer(handshake) else { throw .identityMismatch }
        return conversation
    }
}
