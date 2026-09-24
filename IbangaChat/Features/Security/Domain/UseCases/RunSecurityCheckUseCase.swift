import Foundation

struct RunSecurityCheckUseCase {
    let service: any SecurityServiceProtocol

    func callAsFunction() async -> SecurityReport {
        await service.runDiagnostics()
    }
}
