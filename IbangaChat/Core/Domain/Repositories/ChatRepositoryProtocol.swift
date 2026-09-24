import Foundation

protocol ChatRepositoryProtocol: AnyObject {
    var conversations: [Conversation] { get }

    func start(localIdentity: DeviceIdentity) async
    func conversation(id: Conversation.ID) -> Conversation?
    func conversation(withPeer peerID: Peer.ID) -> Conversation?
    func messages(in conversationID: Conversation.ID) -> [Message]
    func loadMessages(in conversationID: Conversation.ID) async

    @discardableResult
    func registerPeer(_ handshake: PeerHandshake) -> Conversation?
    func sendText(_ text: String, in conversationID: Conversation.ID) async throws(ChatError)
    /// Returns `false` if the message was already stored (a duplicate delivery).
    func storeIncomingText(_ text: String, from envelope: IncomingEnvelope) async throws(ChatError) -> Bool
    func markDelivered(messageID: UUID, by peerID: Peer.ID)
    func setVerified(_ isVerified: Bool, peerID: Peer.ID)
}
