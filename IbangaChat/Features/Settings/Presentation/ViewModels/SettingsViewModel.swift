import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var nameDraft: String
    private(set) var nameError: String?
    private(set) var savedNameCount = 0

    let identity: DeviceIdentity

    private let sessions: any SessionRepositoryProtocol
    private let appearanceSettings: AppearanceSettings
    private let updateDisplayName: UpdateDisplayNameUseCase

    init(
        identity: DeviceIdentity,
        sessions: any SessionRepositoryProtocol,
        appearanceSettings: AppearanceSettings,
        updateDisplayName: UpdateDisplayNameUseCase
    ) {
        self.identity = identity
        self.sessions = sessions
        self.appearanceSettings = appearanceSettings
        self.updateDisplayName = updateDisplayName
        self.nameDraft = sessions.localDisplayName
    }

    var displayName: String { sessions.localDisplayName }
    var appearance: AppearancePreference { appearanceSettings.preference }
    var maximumNameLength: Int { WireProtocol.maximumDisplayNameLength }

    var canSaveName: Bool {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != displayName
    }

    var shortFingerprint: String {
        FingerprintFormatter.format(String(identity.fingerprint.prefix(16)))
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    func saveName() async {
        guard canSaveName else { return }
        do throws(DisplayNameError) {
            try await updateDisplayName(nameDraft)
            nameDraft = displayName
            nameError = nil
            savedNameCount += 1
        } catch .empty {
            nameError = String(localized: "Your name can’t be empty.")
        } catch {
            nameError = String(localized: "Use \(maximumNameLength) characters or fewer.")
        }
    }

    func setAppearance(_ preference: AppearancePreference) {
        appearanceSettings.update(preference)
    }
}
