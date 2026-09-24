import Foundation

struct UserFacingError: Equatable {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(_ error: any Error) {
        switch error {
        case CryptoError.keychain(.interactionNotAllowed):
            self.init(
                title: "Unlock your iPhone",
                message: "Your secure identity is only available while this device is unlocked."
            )
        case CryptoError.invalidKeyMaterial:
            self.init(
                title: "Secure identity unavailable",
                message: "Your identity could not be verified on this device. Nothing has been sent."
            )
        case is CryptoError:
            self.init(
                title: "Something went wrong",
                message: "Your secure identity could not be prepared. Please try again."
            )
        default:
            self.init(
                title: "Ibanga couldn’t start",
                message: "Please close the app and try again."
            )
        }
    }
}
