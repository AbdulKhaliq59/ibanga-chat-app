import Foundation

nonisolated struct SecurityCheck: Identifiable, Equatable, Sendable {
    enum Kind: CaseIterable, Sendable {
        case identityKeyStorage
        case x25519KnownAnswer
        case sessionAgreement
        case invalidPeerKeyRejection
        case hkdfKnownAnswer
        case sessionKeySeparation
        case impostorRejection
        case aesGCMRoundTrip
        case tamperRejection
        case associatedDataBinding
    }

    let kind: Kind
    let passed: Bool

    var id: Kind { kind }
}

nonisolated struct SecurityReport: Equatable, Sendable {
    let checks: [SecurityCheck]

    var passedCount: Int { checks.count(where: \.passed) }
    var allPassed: Bool { !checks.isEmpty && passedCount == checks.count }
}
