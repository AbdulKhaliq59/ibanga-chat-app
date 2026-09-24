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
    private(set) var integrity: IntegrityState = .idle

    let mechanisms: [Mechanism] = [
        Mechanism(label: "Encryption", value: "AES-GCM · 256-bit"),
        Mechanism(label: "Key agreement", value: "X25519 · per connection"),
        Mechanism(label: "Key derivation", value: "HKDF-SHA256"),
        Mechanism(label: "Key storage", value: "iOS Keychain"),
    ]

    private let sessions: any SessionRepositoryProtocol
    private let runSecurityCheck: RunSecurityCheckUseCase

    init(identity: DeviceIdentity, sessions: any SessionRepositoryProtocol, runSecurityCheck: RunSecurityCheckUseCase) {
        self.identity = identity
        self.sessions = sessions
        self.runSecurityCheck = runSecurityCheck
    }

    var hasSecureConnection: Bool { sessions.secureConnectionCount > 0 }

    var connectionSummary: String {
        switch sessions.secureConnectionCount {
        case 0: "No active connection"
        case 1: "1 secure connection"
        case let count: "\(count) secure connections"
        }
    }

    var formattedFingerprint: String {
        FingerprintFormatter.format(identity.fingerprint)
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
        case .sessionAgreement: "Both devices derive the same keys"
        case .invalidPeerKeyRejection: "Invalid peer keys are rejected"
        case .hkdfKnownAnswer: "HKDF matches reference vectors"
        case .sessionKeySeparation: "Every connection gets fresh keys"
        case .impostorRejection: "Impersonation attempts are rejected"
        case .aesGCMRoundTrip: "AES-GCM encrypts and decrypts"
        case .tamperRejection: "Tampered messages are rejected"
        case .associatedDataBinding: "Message headers are authenticated"
        }
    }
}
