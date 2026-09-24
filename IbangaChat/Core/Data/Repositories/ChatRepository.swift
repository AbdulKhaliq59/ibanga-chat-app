import Foundation
import Observation
import SwiftData

@Observable
final class ChatRepository: ChatRepositoryProtocol {
    private(set) var conversations: [Conversation] = []
    private var messagesByConversation: [Conversation.ID: [Message]] = [:]
    private var transfers: [UUID: Double] = [:]

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let crypto: any CryptoServiceProtocol
    @ObservationIgnored private let sessions: any SessionRepositoryProtocol
    @ObservationIgnored private let logger: SecureLogger
    @ObservationIgnored private var localPeerID: Peer.ID?
    @ObservationIgnored private var activeConversationID: Conversation.ID?

    private static let maximumSearchResults = 50
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    init(
        context: ModelContext,
        crypto: any CryptoServiceProtocol,
        sessions: any SessionRepositoryProtocol,
        logger: SecureLogger
    ) {
        self.context = context
        self.crypto = crypto
        self.sessions = sessions
        self.logger = logger
    }

    func start(localIdentity: DeviceIdentity) async {
        guard localPeerID == nil else { return }
        localPeerID = localIdentity.fingerprint
        await reloadConversations()
    }

    // MARK: Queries

    func conversation(id: Conversation.ID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func conversation(withPeer peerID: Peer.ID) -> Conversation? {
        conversations.first { $0.peer.id == peerID }
    }

    func messages(in conversationID: Conversation.ID) -> [Message] {
        messagesByConversation[conversationID] ?? []
    }

    func loadMessages(in conversationID: Conversation.ID) async {
        guard let record = findConversationRecord(id: conversationID) else { return }

        let stored = record.messages
            .sorted { $0.sentAt < $1.sentAt }
            .map(StoredMessage.init)

        var loaded: [Message] = []
        loaded.reserveCapacity(stored.count)
        for message in stored {
            if let decrypted = await decrypt(message, in: record) {
                loaded.append(decrypted)
            }
        }
        messagesByConversation[conversationID] = loaded
    }

    // MARK: Peers

    @discardableResult
    func registerPeer(_ handshake: PeerHandshake) -> Conversation? {
        let peerRecord: PeerRecord
        if let existing = findPeerRecord(id: handshake.peerID) {
            guard existing.publicKey == handshake.identityKey else { return nil }
            peerRecord = existing
        } else {
            peerRecord = PeerRecord(
                displayName: handshake.displayName,
                publicKey: handshake.identityKey,
                fingerprint: handshake.peerID
            )
            context.insert(peerRecord)
        }
        peerRecord.displayName = handshake.displayName
        peerRecord.lastSeenAt = .now

        let conversationRecord: ConversationRecord
        if let existing = peerRecord.conversations.first {
            conversationRecord = existing
        } else {
            conversationRecord = ConversationRecord(peer: peerRecord)
            context.insert(conversationRecord)
        }

        save()
        return refreshSummary(for: conversationRecord, lastMessage: conversation(id: conversationRecord.id)?.lastMessage)
    }

    func setVerified(_ isVerified: Bool, peerID: Peer.ID) {
        guard let peerRecord = findPeerRecord(id: peerID) else { return }
        peerRecord.isVerified = isVerified
        save()
        for record in peerRecord.conversations {
            refreshSummary(for: record, lastMessage: conversation(id: record.id)?.lastMessage)
        }
    }

    // MARK: Messages

    func sendText(_ text: String, in conversationID: Conversation.ID) async throws(ChatError) {
        try await sendOutgoing(.text(text), attachmentData: nil, in: conversationID)
    }

    func sendAttachment(_ draft: AttachmentDraft, in conversationID: Conversation.ID) async throws(ChatError) {
        let attachment = Attachment(
            id: UUID(),
            kind: draft.kind,
            filename: draft.filename,
            contentType: draft.contentType,
            byteCount: draft.data.count
        )
        try await sendOutgoing(.attachment(attachment), attachmentData: draft.data, in: conversationID)
    }

    func resend(messageID: UUID) async throws(ChatError) {
        guard let record = findMessageRecord(id: messageID),
              record.direction == .outgoing,
              record.status == .failed,
              let conversationRecord = record.conversation,
              let peerID = conversationRecord.peer?.fingerprint,
              let message = await decrypt(StoredMessage(record), in: conversationRecord)
        else { throw .conversationNotFound }

        var attachmentData: Data?
        if let attachment = message.attachment {
            guard let data = await self.attachmentData(for: attachment) else { throw .storageFailed }
            attachmentData = data
        }

        updateStatus(of: messageID, to: .sending)
        try await transmit(message.content, attachmentData: attachmentData, messageID: messageID, sentAt: message.sentAt, to: peerID)
    }

    func storeIncoming(_ content: MessageContent, attachmentData: Data?, from envelope: IncomingEnvelope) async throws(ChatError) -> Bool {
        guard let localPeerID,
              let peerRecord = findPeerRecord(id: envelope.peerID),
              let record = peerRecord.conversations.first
        else { throw .conversationNotFound }
        guard findMessageRecord(id: envelope.messageID) == nil else { return false }

        let sentAt = min(envelope.sentAt, .now)
        let sealedBody = try await sealForStorage(content, messageID: envelope.messageID)
        let sealedAttachment = try await sealAttachment(of: content, data: attachmentData)
        guard findMessageRecord(id: envelope.messageID) == nil else { return false }

        let isUnread = activeConversationID != record.id
        let messageRecord = MessageRecord(
            id: envelope.messageID,
            direction: .incoming,
            kind: content.kind,
            status: .received,
            sentAt: sentAt,
            sealedBody: sealedBody,
            isUnread: isUnread,
            conversation: record
        )
        context.insert(messageRecord)
        if let sealedAttachment {
            context.insert(AttachmentRecord(id: sealedAttachment.id, kind: content.kind, sealedContent: sealedAttachment.payload, message: messageRecord))
        }
        record.lastActivityAt = max(record.lastActivityAt, sentAt)
        save()

        insert(Message(
            id: envelope.messageID,
            conversationID: record.id,
            senderID: envelope.peerID,
            recipientID: localPeerID,
            direction: .incoming,
            content: content,
            sentAt: sentAt,
            status: .received,
            isUnread: isUnread
        ), into: record)
        return true
    }

    func setActiveConversation(_ conversationID: Conversation.ID?) {
        activeConversationID = conversationID
        if let conversationID {
            markRead(conversationID)
        }
    }

    /// Searches message text in memory. Decrypted content is never written to a search index.
    func searchMessages(matching query: String) async -> [Message] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let records = try? context.fetch(FetchDescriptor<ConversationRecord>()) else { return [] }

        var matches: [Message] = []
        for record in records {
            let candidates: [Message]
            if let loaded = messagesByConversation[record.id] {
                candidates = loaded
            } else {
                var decrypted: [Message] = []
                for stored in record.messages.filter({ $0.kind == .text }).map(StoredMessage.init) {
                    if let message = await decrypt(stored, in: record) {
                        decrypted.append(message)
                    }
                }
                candidates = decrypted
            }
            guard !Task.isCancelled else { return [] }
            matches += candidates.filter { $0.text?.localizedStandardContains(query) == true }
        }
        return Array(matches.sorted { $0.sentAt > $1.sentAt }.prefix(Self.maximumSearchResults))
    }

    func attachmentData(for attachment: Attachment) async -> Data? {
        var descriptor = FetchDescriptor<AttachmentRecord>(predicate: #Predicate { $0.id == attachment.id })
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return nil }

        do {
            let payload = try SealedPayload(combined: record.sealedContent)
            return try await crypto.openFromStorage(payload, associatedData: Self.storageAssociatedData(forAttachment: attachment.id))
        } catch {
            logger.log(.failure(.persistence, code: "attachment-unreadable"))
            return nil
        }
    }

    func transferProgress(for messageID: UUID) -> Double? {
        transfers[messageID]
    }

    func markDelivered(messageID: UUID, by peerID: Peer.ID) {
        guard let record = findMessageRecord(id: messageID),
              record.direction == .outgoing,
              record.conversation?.peer?.fingerprint == peerID
        else { return }
        updateStatus(of: messageID, to: .delivered)
    }

    // MARK: Private

    private func reloadConversations() async {
        let descriptor = FetchDescriptor<ConversationRecord>(sortBy: [SortDescriptor(\.lastActivityAt, order: .reverse)])
        guard let records = try? context.fetch(descriptor) else { return }

        var summaries: [Conversation] = []
        for record in records {
            guard let peer = record.peer.map(Self.peer) else { continue }
            var lastMessage: Message?
            if let latest = record.messages.max(by: { $0.sentAt < $1.sentAt }) {
                lastMessage = await decrypt(StoredMessage(latest), in: record)
            }
            summaries.append(Conversation(
                id: record.id,
                peer: peer,
                lastMessage: lastMessage,
                lastActivityAt: record.lastActivityAt,
                unreadCount: Self.unreadCount(in: record)
            ))
        }
        conversations = summaries
    }

    @discardableResult
    private func refreshSummary(for record: ConversationRecord, lastMessage: Message?) -> Conversation? {
        guard let peer = record.peer.map(Self.peer) else { return nil }
        let summary = Conversation(
            id: record.id,
            peer: peer,
            lastMessage: lastMessage,
            lastActivityAt: record.lastActivityAt,
            unreadCount: Self.unreadCount(in: record)
        )

        conversations.removeAll { $0.id == record.id }
        let index = conversations.firstIndex { $0.lastActivityAt < summary.lastActivityAt } ?? conversations.endIndex
        conversations.insert(summary, at: index)
        return summary
    }

    private func insert(_ message: Message, into record: ConversationRecord) {
        if var loaded = messagesByConversation[record.id] {
            let index = loaded.lastIndex { $0.sentAt <= message.sentAt }.map { $0 + 1 } ?? 0
            loaded.insert(message, at: index)
            messagesByConversation[record.id] = loaded
        }

        let current = conversation(id: record.id)?.lastMessage
        let latest = current.map { $0.sentAt > message.sentAt ? $0 : message } ?? message
        refreshSummary(for: record, lastMessage: latest)
    }

    private func markRead(_ conversationID: Conversation.ID) {
        guard let record = findConversationRecord(id: conversationID) else { return }
        let unread = record.messages.filter(\.isUnread)
        guard !unread.isEmpty else { return }

        unread.forEach { $0.isUnread = false }
        save()

        if var loaded = messagesByConversation[conversationID] {
            for index in loaded.indices where loaded[index].isUnread {
                loaded[index].isUnread = false
            }
            messagesByConversation[conversationID] = loaded
        }
        refreshSummary(for: record, lastMessage: conversation(id: conversationID)?.lastMessage)
    }

    private static func unreadCount(in record: ConversationRecord) -> Int {
        record.messages.count { $0.isUnread }
    }

    private func updateStatus(of messageID: UUID, to status: MessageStatus, onlyIfCurrently expected: MessageStatus? = nil) {
        guard let record = findMessageRecord(id: messageID), let conversationRecord = record.conversation else { return }
        if let expected, record.status != expected { return }

        record.status = status
        save()

        if var loaded = messagesByConversation[conversationRecord.id],
           let index = loaded.firstIndex(where: { $0.id == messageID }) {
            loaded[index].status = status
            messagesByConversation[conversationRecord.id] = loaded
        }
        if var lastMessage = conversation(id: conversationRecord.id)?.lastMessage, lastMessage.id == messageID {
            lastMessage.status = status
            refreshSummary(for: conversationRecord, lastMessage: lastMessage)
        }
    }

    private func sendOutgoing(_ content: MessageContent, attachmentData: Data?, in conversationID: Conversation.ID) async throws(ChatError) {
        guard let localPeerID,
              let record = findConversationRecord(id: conversationID),
              let peerRecord = record.peer
        else { throw .conversationNotFound }

        let messageID = UUID()
        let sentAt = Date(timeIntervalSince1970: TimeInterval(Date.now.millisecondsSince1970) / 1000)
        let sealedBody = try await sealForStorage(content, messageID: messageID)
        let sealedAttachment = try await sealAttachment(of: content, data: attachmentData)

        let messageRecord = MessageRecord(
            id: messageID,
            direction: .outgoing,
            kind: content.kind,
            status: .sending,
            sentAt: sentAt,
            sealedBody: sealedBody,
            conversation: record
        )
        context.insert(messageRecord)
        if let sealedAttachment {
            context.insert(AttachmentRecord(id: sealedAttachment.id, kind: content.kind, sealedContent: sealedAttachment.payload, message: messageRecord))
        }
        record.lastActivityAt = sentAt
        save()

        insert(Message(
            id: messageID,
            conversationID: conversationID,
            senderID: localPeerID,
            recipientID: peerRecord.fingerprint,
            direction: .outgoing,
            content: content,
            sentAt: sentAt,
            status: .sending
        ), into: record)

        try await transmit(content, attachmentData: attachmentData, messageID: messageID, sentAt: sentAt, to: peerRecord.fingerprint)
    }

    private func transmit(
        _ content: MessageContent,
        attachmentData: Data?,
        messageID: UUID,
        sentAt: Date,
        to peerID: Peer.ID
    ) async throws(ChatError) {
        let payload: SessionPayload
        switch content {
        case .text(let text):
            payload = .text(text)
        case .attachment(let attachment):
            guard let attachmentData else {
                updateStatus(of: messageID, to: .failed)
                throw .storageFailed
            }
            payload = .attachment(attachment, data: attachmentData)
            transfers[messageID] = 0
        }
        defer { transfers[messageID] = nil }

        do {
            try await sessions.send(payload, messageID: messageID, sentAt: sentAt, to: peerID) { [weak self] fraction in
                if self?.transfers[messageID] != nil {
                    self?.transfers[messageID] = fraction
                }
            }
            updateStatus(of: messageID, to: .sent, onlyIfCurrently: .sending)
        } catch {
            updateStatus(of: messageID, to: .failed)
            throw .sendFailed(error)
        }
    }

    private func sealAttachment(of content: MessageContent, data: Data?) async throws(ChatError) -> (id: UUID, payload: SealedPayload)? {
        guard case .attachment(let attachment) = content, let data else { return nil }
        do {
            let sealed = try await crypto.sealForStorage(data, associatedData: Self.storageAssociatedData(forAttachment: attachment.id))
            return (attachment.id, sealed)
        } catch {
            logger.log(.failure(.persistence, code: "attachment-seal-failed"))
            throw .storageFailed
        }
    }

    private func sealForStorage(_ content: MessageContent, messageID: UUID) async throws(ChatError) -> SealedPayload {
        do {
            let plaintext = try Self.encoder.encode(content)
            return try await crypto.sealForStorage(plaintext, associatedData: Self.storageAssociatedData(for: messageID))
        } catch {
            logger.log(.failure(.persistence, code: "seal-failed"))
            throw .storageFailed
        }
    }

    private func decrypt(_ stored: StoredMessage, in record: ConversationRecord) async -> Message? {
        guard let localPeerID, let peerID = record.peer?.fingerprint else { return nil }

        do {
            let payload = try SealedPayload(combined: stored.sealedBody)
            let plaintext = try await crypto.openFromStorage(payload, associatedData: Self.storageAssociatedData(for: stored.id))
            let content = try Self.decoder.decode(MessageContent.self, from: plaintext)
            return Message(
                id: stored.id,
                conversationID: record.id,
                senderID: stored.direction == .outgoing ? localPeerID : peerID,
                recipientID: stored.direction == .outgoing ? peerID : localPeerID,
                direction: stored.direction,
                content: content,
                sentAt: stored.sentAt,
                status: stored.status,
                isUnread: stored.isUnread
            )
        } catch {
            // Content that fails authentication is never displayed.
            logger.log(.failure(.persistence, code: "message-unreadable"))
            return nil
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.log(.failure(.persistence, code: "save-failed"))
        }
    }

    private func findConversationRecord(id: Conversation.ID) -> ConversationRecord? {
        var descriptor = FetchDescriptor<ConversationRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func findPeerRecord(id: Peer.ID) -> PeerRecord? {
        var descriptor = FetchDescriptor<PeerRecord>(predicate: #Predicate { $0.fingerprint == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func findMessageRecord(id: UUID) -> MessageRecord? {
        var descriptor = FetchDescriptor<MessageRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func peer(from record: PeerRecord) -> Peer {
        Peer(id: record.fingerprint, displayName: record.displayName, identityKey: record.publicKey, isVerified: record.isVerified)
    }

    private static func storageAssociatedData(forAttachment attachmentID: UUID) -> Data {
        var data = Data("IbangaChat/v1/storage/attachment".utf8)
        withUnsafeBytes(of: attachmentID.uuid) { data.append(contentsOf: $0) }
        return data
    }

    private static func storageAssociatedData(for messageID: UUID) -> Data {
        var data = Data("IbangaChat/v1/storage/message".utf8)
        withUnsafeBytes(of: messageID.uuid) { data.append(contentsOf: $0) }
        return data
    }
}

private struct StoredMessage {
    let id: UUID
    let direction: MessageDirection
    let status: MessageStatus
    let sentAt: Date
    let sealedBody: Data
    let isUnread: Bool

    init(_ record: MessageRecord) {
        id = record.id
        direction = record.direction
        status = record.status
        sentAt = record.sentAt
        sealedBody = record.sealedBody
        isUnread = record.isUnread
    }
}
