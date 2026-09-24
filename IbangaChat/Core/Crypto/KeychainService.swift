import Foundation
import Security

nonisolated struct KeychainKey: Hashable, Sendable {
    let account: String

    static let identityPrivateKey = KeychainKey(account: "identity.curve25519.key-agreement")
}

nonisolated enum KeychainError: Error, Equatable, Sendable {
    case itemNotFound
    case duplicateItem
    case interactionNotAllowed
    case unexpectedData
    case unhandled(status: OSStatus)

    init(status: OSStatus) {
        switch status {
        case errSecItemNotFound: self = .itemNotFound
        case errSecDuplicateItem: self = .duplicateItem
        case errSecInteractionNotAllowed: self = .interactionNotAllowed
        default: self = .unhandled(status: status)
        }
    }

    var logCode: String {
        switch self {
        case .itemNotFound: "item-not-found"
        case .duplicateItem: "duplicate-item"
        case .interactionNotAllowed: "interaction-not-allowed"
        case .unexpectedData: "unexpected-data"
        case .unhandled(let status): "status-\(status)"
        }
    }
}

nonisolated protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, for key: KeychainKey) throws(KeychainError)
    func read(_ key: KeychainKey) throws(KeychainError) -> Data
    func delete(_ key: KeychainKey) throws(KeychainError)
    func contains(_ key: KeychainKey) throws(KeychainError) -> Bool
}

nonisolated struct KeychainService: KeychainServiceProtocol {
    private let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "IbangaChat") + ".keychain") {
        self.service = service
    }

    func save(_ data: Data, for key: KeychainKey) throws(KeychainError) {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func read(_ key: KeychainKey) throws(KeychainError) -> Data {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data else { throw .unexpectedData }
        return data
    }

    func delete(_ key: KeychainKey) throws(KeychainError) {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    func contains(_ key: KeychainKey) throws(KeychainError) -> Bool {
        var query = baseQuery(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess: return true
        case errSecItemNotFound: return false
        default: throw KeychainError(status: status)
        }
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
