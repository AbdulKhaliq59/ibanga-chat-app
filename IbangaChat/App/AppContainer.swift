import Foundation

final class AppContainer {
    let appState: AppState
    let persistence: PersistenceController

    private let identityRepository: any IdentityRepositoryProtocol
    private let securityService: any SecurityServiceProtocol

    init(
        persistence: PersistenceController,
        identityRepository: any IdentityRepositoryProtocol,
        securityService: any SecurityServiceProtocol
    ) {
        self.persistence = persistence
        self.identityRepository = identityRepository
        self.securityService = securityService
        self.appState = AppState(loadIdentity: LoadIdentityUseCase(repository: identityRepository))
    }

    static func live() throws -> AppContainer {
        let logger = SecureLogger()
        let keychain = KeychainService()
        let crypto = CryptoService(keychain: keychain, logger: logger)

        return AppContainer(
            persistence: try PersistenceController(logger: logger),
            identityRepository: IdentityRepository(crypto: crypto, logger: logger),
            securityService: SecurityService(crypto: crypto, keychain: keychain, logger: logger)
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createIdentity: CreateIdentityUseCase(repository: identityRepository)) { [appState] identity in
            appState.completeOnboarding(with: identity)
        }
    }

    func makeSecurityViewModel(identity: DeviceIdentity) -> SecurityViewModel {
        SecurityViewModel(
            identity: identity,
            connectionState: .inactive,
            runSecurityCheck: RunSecurityCheckUseCase(service: securityService)
        )
    }
}
