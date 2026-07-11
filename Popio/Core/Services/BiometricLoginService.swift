import Foundation
import LocalAuthentication
import Security

struct BiometricCredentials: Codable, Hashable {
    let identifier: String
    let password: String
}

struct BiometricLoginService {
    private let service = "com.popio.app.biometric-login"
    private let account = "saved-login"
    private let savedCredentialsMarkerKey = "com.popio.app.biometric-login.has-saved-credentials"

    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            && context.biometryType == .faceID
    }

    var hasSavedCredentials: Bool {
        if UserDefaults.standard.bool(forKey: savedCredentialsMarkerKey) {
            return true
        }

        let hasExistingCredentials = keychainContainsSavedCredentialsWithoutPrompt()
        if hasExistingCredentials {
            UserDefaults.standard.set(true, forKey: savedCredentialsMarkerKey)
        }
        return hasExistingCredentials
    }

    func save(identifier: String, password: String) throws {
        guard isAvailable else { throw BiometricLoginError.unavailable }

        let credentials = BiometricCredentials(identifier: identifier, password: password)
        let data = try JSONEncoder().encode(credentials)

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw BiometricLoginError.keychainAccessFailed
        }

        SecItemDelete(baseQuery() as CFDictionary)

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessControl as String] = accessControl

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            UserDefaults.standard.set(false, forKey: savedCredentialsMarkerKey)
            throw BiometricLoginError.keychainAccessFailed
        }

        UserDefaults.standard.set(true, forKey: savedCredentialsMarkerKey)
    }

    func loadCredentials() throws -> BiometricCredentials {
        guard isAvailable else { throw BiometricLoginError.unavailable }

        let context = LAContext()
        context.localizedReason = "Use Face ID to log in to Popio."

        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseOperationPrompt as String] = "Use Face ID to log in to Popio."

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            throw BiometricLoginError.authenticationFailed
        }

        return try JSONDecoder().decode(BiometricCredentials.self, from: data)
    }

    func deleteSavedCredentials() {
        SecItemDelete(baseQuery() as CFDictionary)
        UserDefaults.standard.set(false, forKey: savedCredentialsMarkerKey)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainContainsSavedCredentialsWithoutPrompt() -> Bool {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
}

enum BiometricLoginError: LocalizedError {
    case unavailable
    case authenticationFailed
    case keychainAccessFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Face ID is not available or has not been set up on this device."
        case .authenticationFailed:
            return "Face ID login failed."
        case .keychainAccessFailed:
            return "Face ID login could not be saved."
        }
    }
}
