import SwiftData
import SwiftUI

@main
struct IbangaChatApp: App {
    @State private var launch = Result { try AppContainer.live() }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .success(let container):
                RootView(container: container)
                    .modelContainer(container.persistence.modelContainer)
                    .tint(IbangaColors.accent)
            case .failure:
                StartupFailureView(error: UserFacingError(
                    title: "Ibanga couldn’t start",
                    message: "Local storage is unavailable. Please restart the app."
                ))
            }
        }
    }
}
