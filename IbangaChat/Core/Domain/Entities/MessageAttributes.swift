import Foundation

nonisolated enum MessageDirection: String, Codable, Sendable {
    case outgoing
    case incoming
}

nonisolated enum MessageKind: String, Codable, Sendable {
    case text
    case image
    case file
}

nonisolated enum MessageStatus: String, Codable, Sendable {
    case sending
    case sent
    case delivered
    case received
    case failed
}
