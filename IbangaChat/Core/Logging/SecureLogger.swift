import OSLog

nonisolated struct SecureLogger: Sendable {
    enum Category: String, Sendable {
        case app, crypto, keychain, persistence, security
    }

    enum Event: Sendable {
        case identityCreated
        case identityLoaded
        case identityDestroyed
        case staleIdentityPurged
        case sessionEstablished
        case persistenceReady
        case securityCheckCompleted(passed: Int, total: Int)
        /// `code` must be a stable, non-sensitive identifier such as `CryptoError.logCode`.
        case failure(Category, code: String)
    }

    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "IbangaChat") {
        self.subsystem = subsystem
    }

    func log(_ event: Event) {
        switch event {
        case .identityCreated:
            logger(.crypto).notice("Device identity created")
        case .identityLoaded:
            logger(.crypto).debug("Device identity loaded")
        case .identityDestroyed:
            logger(.crypto).notice("Device identity removed")
        case .staleIdentityPurged:
            logger(.security).notice("Identity from a previous installation purged")
        case .sessionEstablished:
            logger(.crypto).info("Secure session established")
        case .persistenceReady:
            logger(.persistence).debug("Persistent store ready")
        case let .securityCheckCompleted(passed, total):
            logger(.security).info("Security check completed: \(passed, privacy: .public)/\(total, privacy: .public) passed")
        case let .failure(category, code):
            logger(category).error("Operation failed: \(code, privacy: .public)")
        }
    }

    private func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
