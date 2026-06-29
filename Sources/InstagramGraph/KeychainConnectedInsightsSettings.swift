import Foundation
import OSLog
import Security

/// A minimal Keychain wrapper used to store credential strings securely.
///
/// `set` reports whether the write actually landed so callers can avoid destructive follow-up
/// actions (such as deleting a plaintext copy) when the Keychain rejects the write.
protocol KeychainStoring: Sendable {
    func string(forKey key: String) -> String?
    @discardableResult func set(_ value: String?, forKey key: String) -> Bool
}

/// Stores values as `kSecClassGenericPassword` items, accessible only after first unlock and
/// never synced to iCloud or included in backups (`...ThisDeviceOnly`).
struct KeychainStore: KeychainStoring {
    private static let logger = Logger(subsystem: "InstagramGraph", category: "keychain")

    let service: String

    init(service: String) {
        self.service = service
    }

    func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func set(_ value: String?, forKey key: String) -> Bool {
        guard let value, let data = value.data(using: .utf8) else {
            let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
            let ok = status == errSecSuccess || status == errSecItemNotFound
            if !ok { Self.logger.error("Keychain delete failed for \(key, privacy: .public): \(status)") }
            return ok
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        var status = SecItemUpdate(baseQuery(forKey: key) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery(forKey: key)
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        let ok = status == errSecSuccess
        if !ok { Self.logger.error("Keychain write failed for \(key, privacy: .public): \(status)") }
        return ok
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

/// Credential store backing ``ConnectedInsightsSettingsProtocol`` with the Keychain.
///
/// The Facebook token and Instagram business-account id are bearer credentials, so they live in
/// the Keychain rather than `UserDefaults`. The non-sensitive `isCorrectSetup` flag stays in
/// `UserDefaults`. Credentials previously persisted in `UserDefaults` (versions ≤ 3.0.2) are
/// migrated into the Keychain on first use so existing users are not logged out.
final class KeychainConnectedInsightsSettings: ConnectedInsightsSettingsProtocol, @unchecked Sendable {
    private enum Key {
        static let isCorrectSetup = "isCorrectSetup"
        static let facebookToken = "fbToken"
        static let instagramBusinessAccountId = "IgBId"
    }

    private let defaults: UserDefaults
    private let keychain: any KeychainStoring

    init(
        defaults: UserDefaults = .standard,
        keychain: any KeychainStoring = KeychainStore(service: "InstagramGraph.credentials")
    ) {
        self.defaults = defaults
        self.keychain = keychain
        migrateLegacyUserDefaultsCredentialsIfNeeded()
    }

    var isCorrectSetup: Bool {
        get { defaults.bool(forKey: Key.isCorrectSetup) }
        set { defaults.set(newValue, forKey: Key.isCorrectSetup) }
    }

    var facebookToken: String? {
        get { keychain.string(forKey: Key.facebookToken) }
        set { keychain.set(newValue, forKey: Key.facebookToken) }
    }

    var instagramBusinessAccountId: String? {
        get { keychain.string(forKey: Key.instagramBusinessAccountId) }
        set { keychain.set(newValue, forKey: Key.instagramBusinessAccountId) }
    }

    /// Moves any credentials left in `UserDefaults` by older versions into the Keychain, then
    /// clears the plaintext copies. Runs at most once per credential.
    ///
    /// The plaintext copy is removed only once the value is confirmed present in the Keychain
    /// (verified by read-back). If the Keychain write fails — e.g. an entitlement issue on
    /// macOS — the `UserDefaults` copy is left in place so the credential is not lost and the
    /// migration can be retried on the next launch.
    private func migrateLegacyUserDefaultsCredentialsIfNeeded() {
        for key in [Key.facebookToken, Key.instagramBusinessAccountId] {
            guard let legacyValue = defaults.string(forKey: key), !legacyValue.isEmpty else {
                continue
            }
            if keychain.string(forKey: key) == nil {
                keychain.set(legacyValue, forKey: key)
                guard keychain.string(forKey: key) == legacyValue else {
                    continue
                }
            }
            defaults.removeObject(forKey: key)
        }
    }
}
