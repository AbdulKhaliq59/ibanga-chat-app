import Foundation

nonisolated struct Peer: Identifiable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    let displayName: String
    let identityKey: Data
    let isVerified: Bool
}

/// A peer as it presented itself during an authenticated handshake.
nonisolated struct PeerHandshake: Hashable, Sendable {
    let peerID: Peer.ID
    let identityKey: Data
    let displayName: String
}

nonisolated struct NearbyDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Fingerprint advertised over Bonjour. Unauthenticated until the handshake confirms it.
    let claimedPeerID: Peer.ID?
}
