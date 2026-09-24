import Observation
import SwiftUI
import UIKit

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    fileprivate var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}


@Observable
final class AppearanceSettings {
    private static let storageKey = "ibanga.appearance"

    private(set) var preference: AppearancePreference

    init() {
        preference = UserDefaults.standard.string(forKey: Self.storageKey)
            .flatMap(AppearancePreference.init(rawValue:)) ?? .system
    }

    func update(_ preference: AppearancePreference) {
        guard preference != self.preference else { return }
        self.preference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Self.storageKey)
        apply(animated: true)
    }

    func apply(animated: Bool = false) {
        let style = preference.interfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for window in windows {
            if animated {
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                    window.overrideUserInterfaceStyle = style
                }
            } else {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
