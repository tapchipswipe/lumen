import CryptoKit
import Foundation
import Security

/// AES-GCM encryption for archives, with the 256-bit key held in the Keychain.
enum CryptoVault {
    private static let service = "com.lumen.app.archive-key"
    private static let account = "archive-256"

    // MARK: - Keychain

    static func keyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    static func saveKeyToKeychain(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            Log.sync.error("Keychain key save failed: \(status)")
        }
    }

    /// Loads the stored key or creates + persists a new one.
    static func currentKey() -> SymmetricKey {
        if let k = keyFromKeychain() { return k }
        let k = SymmetricKey(size: .bits256)
        saveKeyToKeychain(k)
        Log.sync.info("Created new archive encryption key")
        return k
    }

    // MARK: - Cipher (pure, testable)

    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else {
            throw NSError(domain: "CryptoVault", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "seal produced no combined data"])
        }
        return combined
    }

    static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}
