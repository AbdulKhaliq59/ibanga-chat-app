import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    enum Step {
        case welcome
        case identity
    }

    enum IdentityState: Equatable {
        case idle
        case creating
        case created
        case failed(UserFacingError)
    }

    private(set) var step: Step = .welcome
    private(set) var identityState: IdentityState = .idle

    private let createIdentity: CreateIdentityUseCase
    private let onComplete: (DeviceIdentity) -> Void

    init(createIdentity: CreateIdentityUseCase, onComplete: @escaping (DeviceIdentity) -> Void) {
        self.createIdentity = createIdentity
        self.onComplete = onComplete
    }

    func continueToIdentity() {
        step = .identity
    }

    func createSecureIdentity() async {
        guard identityState != .creating, identityState != .created else { return }
        identityState = .creating

        do {
            let identity = try await createIdentity()
            identityState = .created
            try? await Task.sleep(for: .milliseconds(900))
            onComplete(identity)
        } catch {
            identityState = .failed(UserFacingError(error))
        }
    }
}
