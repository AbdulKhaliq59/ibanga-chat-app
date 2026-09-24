import Foundation
import Observation

@Observable
final class ChatViewModel {
    struct Row: Identifiable, Equatable {
        enum Kind: Equatable {
            case day(Date)
            case message(Message, isFirstInGroup: Bool, isLastInGroup: Bool)
        }

        let id: String
        let kind: Kind
    }

    private static let groupingInterval: TimeInterval = 3 * 60

    let conversationID: Conversation.ID
    var draft = ""
    private(set) var notice: String?
    private(set) var isReconnecting = false
    private(set) var hasLoaded = false

    private let chat: any ChatRepositoryProtocol
    private let sessions: any SessionRepositoryProtocol
    private let sendMessage: SendMessageUseCase
    private let reconnectToPeer: ReconnectToPeerUseCase
    private let makePeerSecurity: (Peer.ID) -> PeerSecurityViewModel

    init(
        conversationID: Conversation.ID,
        chat: any ChatRepositoryProtocol,
        sessions: any SessionRepositoryProtocol,
        sendMessage: SendMessageUseCase,
        reconnectToPeer: ReconnectToPeerUseCase,
        makePeerSecurity: @escaping (Peer.ID) -> PeerSecurityViewModel
    ) {
        self.conversationID = conversationID
        self.chat = chat
        self.sessions = sessions
        self.sendMessage = sendMessage
        self.reconnectToPeer = reconnectToPeer
        self.makePeerSecurity = makePeerSecurity
    }

    var peer: Peer? { chat.conversation(id: conversationID)?.peer }
    var messages: [Message] { chat.messages(in: conversationID) }

    var connectionState: SecureConnectionState {
        peer.map { sessions.connectionState(for: $0.id) } ?? .inactive
    }

    var canSend: Bool {
        connectionState == .secure && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func load() async {
        await chat.loadMessages(in: conversationID)
        hasLoaded = true
    }

    func send() async {
        let text = draft
        draft = ""
        notice = nil

        do {
            try await sendMessage(text, in: conversationID)
        } catch .emptyMessage {
            return
        } catch .messageTooLong {
            draft = text
            notice = "Messages can be up to \(SendMessageUseCase.maximumLength.formatted()) characters."
        } catch .notSecure {
            draft = text
            notice = "Messages are only sent over a secure connection."
        } catch {
            notice = "Your message couldn’t be sent securely."
        }
    }

    func reconnect() async {
        guard let peer, !isReconnecting else { return }
        isReconnecting = true
        notice = nil
        defer { isReconnecting = false }

        do {
            try await reconnectToPeer(peer.id)
        } catch .peerUnavailable {
            notice = "\(peer.displayName) isn’t nearby. Ask them to open Ibanga."
        } catch .identityMismatch {
            notice = "This device’s identity has changed. Messages were not sent."
        } catch {
            notice = "Secure connection could not be established. Please try again."
        }
    }

    func makePeerSecurityViewModel() -> PeerSecurityViewModel? {
        peer.map { makePeerSecurity($0.id) }
    }

    private static func isGrouped(_ first: Message?, _ second: Message?, calendar: Calendar) -> Bool {
        guard let first, let second else { return false }
        return first.direction == second.direction
            && second.sentAt.timeIntervalSince(first.sentAt) < groupingInterval
            && calendar.isDate(first.sentAt, inSameDayAs: second.sentAt)
    }
}
