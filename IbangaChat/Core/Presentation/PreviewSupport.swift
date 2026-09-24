#if DEBUG
import Foundation

nonisolated struct PreviewIdentityRepository: IdentityRepositoryProtocol {
    static let identity = DeviceIdentity(
        publicKey: Data(repeating: 0xA5, count: 32),
        fingerprint: "47a231d1b6b201a8d05057e52d719e34"
    )

    func currentIdentity() async throws -> DeviceIdentity? { Self.identity }
    func createIdentity() async throws -> DeviceIdentity { Self.identity }
}
#endif
