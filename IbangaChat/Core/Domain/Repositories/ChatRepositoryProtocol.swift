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
    func sendAttachment(_ draft: AttachmentDraft, in conversationID: Conversation.ID) async throws(ChatError)
    /// Retransmits a failed outgoing message with its original ID, so the receiver can de-duplicate.
    func resend(messageID: UUID) async throws(ChatError)
    /// Returns `false` if the message was already stored (a duplicate delivery).
    func storeIncoming(_ content: MessageContent, attachmentData: Data?, from envelope: IncomingEnvelope) async throws(ChatError) -> Bool
    /// Decrypts attachment bytes on demand; they are never held for the whole conversation.
    func attachmentData(for attachment: Attachment) async -> Data?
    /// Fraction of an outgoing attachment transmitted so far, or `nil` when not transferring.
    func transferProgress(for messageID: UUID) -> Double?
    func markDelivered(messageID: UUID, by peerID: Peer.ID)
    func setVerified(_ isVerified: Bool, peerID: Peer.ID)
}
