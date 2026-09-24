import Foundation

nonisolated struct IdentityRepository: IdentityRepositoryProtocol {
    private static let installationMarkerKey = "ibanga.installation.marker"

    private let crypto: any CryptoServiceProtocol
    private let logger: SecureLogger

    init(crypto: any CryptoServiceProtocol, logger: SecureLogger) {
        self.crypto = crypto
        self.logger = logger
    }

    func currentIdentity() async throws -> DeviceIdentity? {
        try await purgeIdentityFromPreviousInstallation()
        return try await crypto.loadIdentity()
    }

    func createIdentity() async throws -> DeviceIdentity {
        try await crypto.createIdentity()
    }

    private func purgeIdentityFromPreviousInstallation() async throws {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.installationMarkerKey) else { return }

        try await crypto.destroyIdentity()
        defaults.set(true, forKey: Self.installationMarkerKey)
        logger.log(.staleIdentityPurged)
    }
}
