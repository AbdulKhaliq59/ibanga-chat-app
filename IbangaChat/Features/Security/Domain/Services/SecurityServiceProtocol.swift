import Foundation

nonisolated protocol SecurityServiceProtocol: Sendable {
    func runDiagnostics() async -> SecurityReport
}
