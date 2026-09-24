import SwiftData
import SwiftUI

final class AppContainer {
    let appState: AppState
    let persistence: PersistenceController
    let appearance = AppearanceSettings()

    private let identityRepository: any IdentityRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    private let chatRepository: any ChatRepositoryProtocol
    private let securityService: any SecurityServiceProtocol
    private let attachments: any AttachmentProcessing = AttachmentProcessor()
    private var messagePump: Task<Void, Never>?

    init(
        persistence: PersistenceController,
        identityRepository: any IdentityRepositoryProtocol,
        sessionRepository: any SessionRepositoryProtocol,
        chatRepository: any ChatRepositoryProtocol,
        securityService: any SecurityServiceProtocol
    ) {
        self.persistence = persistence
        self.identityRepository = identityRepository
        self.sessionRepository = sessionRepository
        self.chatRepository = chatRepository
        self.securityService = securityService
        self.appState = AppState(loadIdentity: LoadIdentityUseCase(repository: identityRepository))
    }

    static func live() throws -> AppContainer {
        let logger = SecureLogger()
        let keychain = KeychainService()
        let crypto = CryptoService(keychain: keychain, logger: logger)
        let persistence = try PersistenceController(logger: logger)
        let sessions = SessionRepository(
            network: NetworkService(logger: logger),
            crypto: crypto,
            defaultDisplayName: UIDevice.current.name,
            logger: logger
        )
        let chat = ChatRepository(
            context: persistence.modelContainer.mainContext,
            crypto: crypto,
            sessions: sessions,
            logger: logger
        )

        return AppContainer(
            persistence: persistence,
            identityRepository: IdentityRepository(crypto: crypto, logger: logger),
            sessionRepository: sessions,
            chatRepository: chat,
            securityService: SecurityService(crypto: crypto, keychain: keychain, logger: logger)
        )
    }

    /// Starts discovery, secure sessions and the inbound message pipeline. Idempotent.
    func startMessaging(with identity: DeviceIdentity) async {
        guard messagePump == nil else { return }

        let chat = chatRepository
        let sessions = sessionRepository
        let receiveMessage = ReceiveMessageUseCase(chat: chat, sessions: sessions, attachments: attachments)
        attachments.removePreviewFiles()
        messagePump = Task {
            for await event in sessions.events {
                switch event {
                case .established(let handshake):
                    chat.registerPeer(handshake)
                case .received(let envelope):
                    await receiveMessage(envelope)
                }
            }
        }

        await chat.start(localIdentity: identity)
        sessions.rememberPeers(chat.conversations.map(\.peer.id))
        await sessions.start(localIdentity: identity)
    }

    // MARK: Factories

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(createIdentity: CreateIdentityUseCase(repository: identityRepository)) { [appState] identity in
            appState.completeOnboarding(with: identity)
        }
    }

    func makeConversationsView(identity: DeviceIdentity) -> ConversationsView {
        ConversationsView(
            viewModel: ConversationsViewModel(chat: chatRepository, sessions: sessionRepository),
            destinations: ConversationsDestinations(
                chat: { [unowned self] id in AnyView(ChatView(viewModel: makeChatViewModel(conversationID: id))) },
                settings: { [unowned self] in AnyView(makeSettingsView(identity: identity)) },
                pairing: { [unowned self] onConnected in
                    AnyView(PairingView(viewModel: makePairingViewModel(onConnected: onConnected)))
                }
            )
        )
    }

    func makeChatViewModel(conversationID: Conversation.ID) -> ChatViewModel {
        ChatViewModel(
            conversationID: conversationID,
            chat: chatRepository,
            sessions: sessionRepository,
            attachments: attachments,
            actions: ChatViewModel.Actions(
                sendMessage: SendMessageUseCase(chat: chatRepository, sessions: sessionRepository),
                sendAttachment: SendAttachmentUseCase(chat: chatRepository, sessions: sessionRepository),
                resendMessage: ResendMessageUseCase(chat: chatRepository, sessions: sessionRepository),
                reconnectToPeer: ReconnectToPeerUseCase(chat: chatRepository, sessions: sessionRepository)
            ),
            makePeerSecurity: { [unowned self] peerID in
                PeerSecurityViewModel(peerID: peerID, chat: chatRepository, sessions: sessionRepository)
            }
        )
    }

    func makePairingViewModel(onConnected: @escaping (Conversation.ID) -> Void) -> PairingViewModel {
        PairingViewModel(
            sessions: sessionRepository,
            connectToPeer: ConnectToPeerUseCase(chat: chatRepository, sessions: sessionRepository),
            onConnected: onConnected
        )
    }

    func makeSettingsView(identity: DeviceIdentity) -> SettingsView {
        SettingsView(
            viewModel: SettingsViewModel(
                identity: identity,
                sessions: sessionRepository,
                appearanceSettings: appearance,
                updateDisplayName: UpdateDisplayNameUseCase(sessions: sessionRepository)
            ),
            securityDestination: { [unowned self] in
                AnyView(SecurityView(viewModel: makeSecurityViewModel(identity: identity)))
            }
        )
    }

    func makeSecurityViewModel(identity: DeviceIdentity) -> SecurityViewModel {
        SecurityViewModel(
            identity: identity,
            sessions: sessionRepository,
            runSecurityCheck: RunSecurityCheckUseCase(service: securityService)
        )
    }
}
