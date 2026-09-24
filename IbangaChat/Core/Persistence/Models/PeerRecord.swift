import Foundation
import SwiftData

@Model
final class PeerRecord {
    @Attribute(.unique) var id: UUID
    var displayName: String
    @Attribute(.unique) var publicKey: Data
    var fingerprint: String
    var isVerified: Bool
    var firstSeenAt: Date
    var lastSeenAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ConversationRecord.peer)
    var conversations: [ConversationRecord] = []

    init(
        id: UUID = UUID(),
        displayName: String,
        publicKey: Data,
        fingerprint: String,
        isVerified: Bool = false,
        firstSeenAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.publicKey = publicKey
        self.fingerprint = fingerprint
        self.isVerified = isVerified
        self.firstSeenAt = firstSeenAt
    }
}
