import Foundation

struct LoadIdentityUseCase {
    let repository: any IdentityRepositoryProtocol

    func callAsFunction() async throws -> DeviceIdentity? {
        try await repository.currentIdentity()
    }
}
