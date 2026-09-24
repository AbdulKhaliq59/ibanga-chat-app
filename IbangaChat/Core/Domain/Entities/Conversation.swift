import Foundation

nonisolated struct Conversation: Identifiable, Hashable, Sendable {
    let id: UUID
    let peer: Peer
    let lastMessage: Message?
    let lastActivityAt: Date
    var unreadCount = 0
}
