import Foundation
import SwiftData

@Model
final class ConversationRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var lastActivityAt: Date
    var peer: PeerRecord?

    @Relationship(deleteRule: .cascade, inverse: \MessageRecord.conversation)
    var messages: [MessageRecord] = []

    init(id: UUID = UUID(), peer: PeerRecord, createdAt: Date = .now) {
        self.id = id
        self.peer = peer
        self.createdAt = createdAt
        self.lastActivityAt = createdAt
    }
}
