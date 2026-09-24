import Foundation

nonisolated protocol IdentityRepositoryProtocol: Sendable {
    func currentIdentity() async throws -> DeviceIdentity?
    func createIdentity() async throws -> DeviceIdentity
}
