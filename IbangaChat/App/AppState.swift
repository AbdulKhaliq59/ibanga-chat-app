import Foundation
import Observation

@Observable
final class AppState {
    enum Phase: Equatable {
        case launching
        case onboarding
        case ready(DeviceIdentity)
        case failed(UserFacingError)
    }

    private(set) var phase: Phase = .launching

    private let loadIdentity: LoadIdentityUseCase

    init(loadIdentity: LoadIdentityUseCase) {
        self.loadIdentity = loadIdentity
    }

    func bootstrap() async {
        phase = .launching
        do {
            if let identity = try await loadIdentity() {
                phase = .ready(identity)
            } else {
                phase = .onboarding
            }
        } catch {
            phase = .failed(UserFacingError(error))
        }
    }

    func completeOnboarding(with identity: DeviceIdentity) {
        phase = .ready(identity)
    }
}
