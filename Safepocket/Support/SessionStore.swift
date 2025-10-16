import Foundation
import Security

protocol SessionStore: AnyObject {
    var session: AuthSession? { get set }
}

#if DEBUG
final class InMemorySessionStore: SessionStore {
    var session: AuthSession?
}
#endif

final class KeychainSessionStore: SessionStore {
    private let service = "shoutaSuzuki.Safepocket.auth"
    private let account = "primary-session"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    var session: AuthSession? {
        get {
            guard let data = readItem() else {
                return nil
            }
            return try? decoder.decode(AuthSession.self, from: data)
        }
        set {
            if let newValue = newValue, let data = try? encoder.encode(newValue) {
                _ = saveItem(data: data)
            } else {
                _ = deleteItem()
            }
        }
    }

    private func readItem() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            return nil
        }
    }

    @discardableResult
    private func saveItem(data: Data) -> Bool {
        deleteItem()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    private func deleteItem() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
