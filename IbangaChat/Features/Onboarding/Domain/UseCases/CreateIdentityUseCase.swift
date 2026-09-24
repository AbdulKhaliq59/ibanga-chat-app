import Foundation

struct CreateIdentityUseCase {
    let repository: any IdentityRepositoryProtocol

    func callAsFunction() async throws -> DeviceIdentity {
        try await repository.createIdentity()
    }
}
