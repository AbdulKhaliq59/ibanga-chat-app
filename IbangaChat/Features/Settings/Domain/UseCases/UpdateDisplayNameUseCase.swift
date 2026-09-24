import Foundation

nonisolated enum DisplayNameError: Error, Equatable, Sendable {
    case empty
    case tooLong
}

struct UpdateDisplayNameUseCase {
    let sessions: any SessionRepositoryProtocol

    func callAsFunction(_ name: String) async throws(DisplayNameError) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        guard trimmed.count <= WireProtocol.maximumDisplayNameLength else { throw .tooLong }

        await sessions.updateLocalDisplayName(trimmed)
    }
}
