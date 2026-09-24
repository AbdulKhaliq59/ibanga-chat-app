import Foundation
import Observation

@Observable
final class PeerSecurityViewModel {
    let peerID: Peer.ID
    private(set) var verificationCode: String?

    private let chat: any ChatRepositoryProtocol
    private let sessions: any SessionRepositoryProtocol

    init(peerID: Peer.ID, chat: any ChatRepositoryProtocol, sessions: any SessionRepositoryProtocol) {
        self.peerID = peerID
        self.chat = chat
        self.sessions = sessions
    }

    var peer: Peer? { chat.conversation(withPeer: peerID)?.peer }
    var connectionState: SecureConnectionState { sessions.connectionState(for: peerID) }
    var isVerified: Bool { peer?.isVerified ?? false }

    var formattedFingerprint: String {
        peer.map { FingerprintFormatter.format($0.id) } ?? ""
    }

    func load() async {
        guard let peer else { return }
        verificationCode = await sessions.verificationCode(for: peer)
    }

    func setVerified(_ isVerified: Bool) {
        chat.setVerified(isVerified, peerID: peerID)
    }
}
