#if DEBUG
import Foundation

nonisolated struct PreviewSecurityService: SecurityServiceProtocol {
    func runDiagnostics() async -> SecurityReport {
        SecurityReport(checks: SecurityCheck.Kind.allCases.map { SecurityCheck(kind: $0, passed: true) })
    }
}
#endif
