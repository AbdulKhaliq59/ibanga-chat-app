import Foundation
import Observation

@Observable
final class SecurityViewModel {
    enum IntegrityState: Equatable {
        case idle
        case running
        case completed(SecurityReport)
    }

    struct Mechanism: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let identity: DeviceIdentity
    let connectionState: SecureConnectionState
    private(set) var integrity: IntegrityState = .idle

    let mechanisms: [Mechanism] = [
        Mechanism(label: "Encryption", value: "AES-GCM · 256-bit"),
        Mechanism(label: "Key agreement", value: "X25519"),
        Mechanism(label: "Key derivation", value: "HKDF-SHA256"),
        Mechanism(label: "Key storage", value: "iOS Keychain"),
    ]

    private let runSecurityCheck: RunSecurityCheckUseCase

    init(identity: DeviceIdentity, connectionState: SecureConnectionState, runSecurityCheck: RunSecurityCheckUseCase) {
        self.identity = identity
        self.connectionState = connectionState
        self.runSecurityCheck = runSecurityCheck
    }

    var formattedFingerprint: String {
        stride(from: 0, to: identity.fingerprint.count, by: 4)
            .map { offset in
                let start = identity.fingerprint.index(identity.fingerprint.startIndex, offsetBy: offset)
                let end = identity.fingerprint.index(start, offsetBy: 4, limitedBy: identity.fingerprint.endIndex)
                    ?? identity.fingerprint.endIndex
                return identity.fingerprint[start..<end].uppercased()
            }
            .joined(separator: " ")
    }

    func runChecks() async {
        guard integrity != .running else { return }
        integrity = .running
        integrity = .completed(await runSecurityCheck())
    }
}

extension SecurityCheck.Kind {
    var title: String {
        switch self {
        case .identityKeyStorage: "Identity key stored in Keychain"
        case .x25519KnownAnswer: "X25519 matches reference vectors"
        case .x25519Agreement: "Both devices derive the same key"
        case .invalidPeerKeyRejection: "Invalid peer keys are rejected"
        case .hkdfKnownAnswer: "HKDF matches reference vectors"
        case .sessionKeySeparation: "Each peer gets a unique key"
        case .aesGCMRoundTrip: "AES-GCM encrypts and decrypts"
        case .tamperRejection: "Tampered messages are rejected"
        case .associatedDataBinding: "Message headers are authenticated"
        }
    }
}

extension SecureConnectionState {
    var title: String {
        switch self {
        case .inactive: "No active connection"
        case .connecting: "Connecting…"
        case .establishingSession: "Establishing secure session…"
        case .secure: "Secure connection"
        case .failed: "Secure connection unavailable"
        }
    }
}
