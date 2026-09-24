import CoreGraphics
import Foundation
import Observation

@Observable
final class ChatViewModel {
    struct Row: Identifiable, Equatable {
        enum Kind: Equatable {
            case day(Date)
            case unreadDivider(count: Int)
            case message(Message, isFirstInGroup: Bool, isLastInGroup: Bool)
        }

        let id: String
        let kind: Kind
    }

    struct Actions {
        let sendMessage: SendMessageUseCase
        let sendAttachment: SendAttachmentUseCase
        let resendMessage: ResendMessageUseCase
        let reconnectToPeer: ReconnectToPeerUseCase
    }

    static let unreadDividerID = "unread-divider"
    private static let groupingInterval: TimeInterval = 3 * 60
    private static let bubbleThumbnailSize = 720
    private static let composerThumbnailSize = 180
    private static let viewerImageSize = 3000

    let conversationID: Conversation.ID
    var draft = ""
    var previewURL: URL?
    private(set) var pendingAttachment: AttachmentDraft?
    private(set) var pendingThumbnail: CGImage?
    private(set) var isPreparingAttachment = false
    private(set) var notice: String?
    private(set) var isReconnecting = false
    private(set) var hasLoaded = false
    /// Where "unread messages" begins, captured when the chat opens and kept until it closes.
    private(set) var firstUnreadMessageID: UUID?
    private(set) var unreadCountAtOpen = 0

    private let chat: any ChatRepositoryProtocol
    private let sessions: any SessionRepositoryProtocol
    private let attachments: any AttachmentProcessing
    private let actions: Actions
    private let makePeerSecurity: (Peer.ID) -> PeerSecurityViewModel
    @ObservationIgnored private var thumbnails: [Attachment.ID: CGImage] = [:]

    init(
        conversationID: Conversation.ID,
        chat: any ChatRepositoryProtocol,
        sessions: any SessionRepositoryProtocol,
        attachments: any AttachmentProcessing,
        actions: Actions,
        makePeerSecurity: @escaping (Peer.ID) -> PeerSecurityViewModel
    ) {
        self.conversationID = conversationID
        self.chat = chat
        self.sessions = sessions
        self.attachments = attachments
        self.actions = actions
        self.makePeerSecurity = makePeerSecurity
    }

    // MARK: State

    var peer: Peer? { chat.conversation(id: conversationID)?.peer }
    var messages: [Message] { chat.messages(in: conversationID) }

    var connectionState: SecureConnectionState {
        peer.map { sessions.connectionState(for: $0.id) } ?? .inactive
    }

    var incomingTransferProgress: Double? {
        peer.flatMap { sessions.incomingTransferProgress(from: $0.id) }
    }

    var canSend: Bool {
        guard connectionState == .secure, !isPreparingAttachment else { return false }
        return pendingAttachment != nil || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func transferProgress(for message: Message) -> Double? {
        chat.transferProgress(for: message.id)
    }

    var rows: [Row] {
        let calendar = Calendar.current
        let messages = messages
        var rows: [Row] = []

        for (index, message) in messages.enumerated() {
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil

            if previous.map({ !calendar.isDate($0.sentAt, inSameDayAs: message.sentAt) }) ?? true {
                rows.append(Row(id: "day-\(message.id)", kind: .day(message.sentAt)))
            }
            if message.id == firstUnreadMessageID {
                rows.append(Row(id: Self.unreadDividerID, kind: .unreadDivider(count: unreadCountAtOpen)))
            }
            rows.append(Row(
                id: message.id.uuidString,
                kind: .message(
                    message,
                    isFirstInGroup: !Self.isGrouped(previous, message, calendar: calendar),
                    isLastInGroup: !Self.isGrouped(message, next, calendar: calendar)
                )
            ))
        }
        return rows
    }

    // MARK: Lifecycle

    func load() async {
        await chat.loadMessages(in: conversationID)
        let unread = messages.filter(\.isUnread)
        firstUnreadMessageID = unread.first?.id
        unreadCountAtOpen = unread.count
        hasLoaded = true
        chat.setActiveConversation(conversationID)
    }

    func setVisible(_ isVisible: Bool) {
        guard hasLoaded else { return }
        chat.setActiveConversation(isVisible ? conversationID : nil)
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: Sending

    func send() async {
        let attachment = pendingAttachment
        let text = draft
        pendingAttachment = nil
        pendingThumbnail = nil
        draft = ""
        notice = nil

        if let attachment {
            do {
                try await actions.sendAttachment(attachment, in: conversationID)
            } catch .notSecure {
                pendingAttachment = attachment
                draft = text
                notice = String(localized: "Attachments are only sent over a secure connection.")
                return
            } catch {
                notice = String(localized: "Your attachment couldn’t be sent securely.")
            }
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await actions.sendMessage(text, in: conversationID)
        } catch .messageTooLong {
            draft = text
            notice = String(localized: "Messages can be up to \(SendMessageUseCase.maximumLength.formatted()) characters.")
        } catch .notSecure {
            draft = text
            notice = String(localized: "Messages are only sent over a secure connection.")
        } catch .emptyMessage {
            return
        } catch {
            notice = String(localized: "Your message couldn’t be sent securely.")
        }
    }

    func retry(_ message: Message) async {
        notice = nil
        do {
            try await actions.resendMessage(message)
        } catch .notSecure {
            notice = String(localized: "Reconnect to send this message securely.")
        } catch {
            notice = String(localized: "Your message couldn’t be sent securely.")
        }
    }

    // MARK: Attachments

    func attach(imageData: Data) async {
        await prepareAttachment { () async throws(AttachmentError) in
            try await attachments.prepareImage(imageData)
        }
    }

    func attach(fileAt url: URL) async {
        await prepareAttachment { () async throws(AttachmentError) in
            try await attachments.prepareFile(at: url)
        }
    }

    func removePendingAttachment() {
        pendingAttachment = nil
        pendingThumbnail = nil
    }

    func thumbnail(for attachment: Attachment) async -> CGImage? {
        if let cached = thumbnails[attachment.id] { return cached }
        guard let data = await chat.attachmentData(for: attachment),
              let image = await attachments.thumbnail(from: data, maxPixelSize: Self.bubbleThumbnailSize)
        else { return nil }
        thumbnails[attachment.id] = image
        return image
    }

    func fullImage(for attachment: Attachment) async -> CGImage? {
        guard let data = await chat.attachmentData(for: attachment) else { return nil }
        return await attachments.thumbnail(from: data, maxPixelSize: Self.viewerImageSize)
    }

    func open(_ attachment: Attachment) async {
        guard let data = await chat.attachmentData(for: attachment) else {
            notice = String(localized: "This attachment couldn’t be opened.")
            return
        }
        do {
            previewURL = try attachments.makePreviewFile(for: attachment, data: data)
        } catch {
            notice = String(localized: "This attachment couldn’t be opened.")
        }
    }

    func previewDismissed() {
        attachments.removePreviewFiles()
    }

    // MARK: Connection

    func reconnect() async {
        guard let peer, !isReconnecting else { return }
        isReconnecting = true
        notice = nil
        defer { isReconnecting = false }

        do {
            try await actions.reconnectToPeer(peer.id)
        } catch .peerUnavailable {
            notice = String(localized: "\(peer.displayName) isn’t nearby. Ask them to open Ibanga.")
        } catch .identityMismatch {
            notice = String(localized: "This device’s identity has changed. Nothing was sent.")
        } catch {
            notice = String(localized: "Unable to establish a secure connection. Try again.")
        }
    }

    func makePeerSecurityViewModel() -> PeerSecurityViewModel? {
        peer.map { makePeerSecurity($0.id) }
    }

    // MARK: Private

    private func prepareAttachment(_ prepare: () async throws(AttachmentError) -> AttachmentDraft) async {
        isPreparingAttachment = true
        notice = nil
        defer { isPreparingAttachment = false }

        do {
            let prepared = try await prepare()
            pendingThumbnail = prepared.kind == .image
                ? await attachments.thumbnail(from: prepared.data, maxPixelSize: Self.composerThumbnailSize)
                : nil
            pendingAttachment = prepared
        } catch .tooLarge {
            notice = String(localized: "Attachments can be up to \(ByteCountFormatter.string(fromByteCount: Int64(Attachment.maximumByteCount), countStyle: .file)).")
        } catch {
            notice = String(localized: "This attachment couldn’t be added.")
        }
    }

    private static func isGrouped(_ first: Message?, _ second: Message?, calendar: Calendar) -> Bool {
        guard let first, let second else { return false }
        return first.direction == second.direction
            && second.sentAt.timeIntervalSince(first.sentAt) < groupingInterval
            && calendar.isDate(first.sentAt, inSameDayAs: second.sentAt)
    }
}
