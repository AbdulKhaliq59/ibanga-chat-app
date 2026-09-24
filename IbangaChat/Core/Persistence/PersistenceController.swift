import Foundation
import SwiftData

final class PersistenceController {
    static let schema = Schema([
        PeerRecord.self,
        ConversationRecord.self,
        MessageRecord.self,
        AttachmentRecord.self,
    ])

    let modelContainer: ModelContainer

    init(inMemory: Bool = false, logger: SecureLogger) throws {
        let configuration = if inMemory {
            ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)
        } else {
            ModelConfiguration(schema: Self.schema, url: try Self.storeURL(), cloudKitDatabase: .none)
        }

        do {
            modelContainer = try ModelContainer(for: Self.schema, configurations: configuration)
        } catch {
            logger.log(.failure(.persistence, code: "container-unavailable"))
            throw error
        }
        logger.log(.persistenceReady)
    }

    private static func storeURL() throws -> URL {
        var directory = URL.applicationSupportDirectory.appending(path: "Ibanga", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try directory.setResourceValues(resourceValues)

        return directory.appending(path: "Ibanga.store")
    }
}
