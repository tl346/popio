import Combine
import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var isRegistering = false
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published private(set) var canUseBiometricLogin = false

    private let biometricLoginService = BiometricLoginService()
    private var currentAppleNonce: String?

    private enum RegistrationLimits {
        static let firstName = 30
        static let lastName = 30
        static let email = 254
        static let displayName = 30
        static let password = 128
    }

    init() {
        refreshBiometricAvailability()
    }

    func refreshBiometricAvailability() {
        canUseBiometricLogin = biometricLoginService.isAvailable && biometricLoginService.hasSavedCredentials
    }

    func submit(using session: AppSession) async {
        errorMessage = nil
        isSubmitting = true
        defer {
            isSubmitting = false
            refreshBiometricAvailability()
        }

        if isRegistering {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = username.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedFirstName.isEmpty,
                  !trimmedLastName.isEmpty,
                  !trimmedEmail.isEmpty,
                  !displayName.isEmpty,
                  !password.isEmpty else {
                errorMessage = "First name, last name, display name, email, and password are required."
                return
            }

            guard trimmedFirstName.count <= RegistrationLimits.firstName,
                  trimmedLastName.count <= RegistrationLimits.lastName,
                  trimmedEmail.count <= RegistrationLimits.email,
                  displayName.count <= RegistrationLimits.displayName,
                  password.count <= RegistrationLimits.password,
                  confirmPassword.count <= RegistrationLimits.password else {
                errorMessage = "One or more fields exceeds the character limit."
                return
            }

            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }

            guard isValidPassword(password) else {
                errorMessage = "Password must be at least 8 characters and include 1 uppercase letter, 1 number, and 1 special character."
                return
            }

            guard !isDisplayNameTaken(displayName, in: session) else {
                errorMessage = "That display name is already taken."
                return
            }

            do {
                try await session.register(
                    username: displayName,
                    email: trimmedEmail,
                    password: password,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName
                )
                try? biometricLoginService.save(identifier: trimmedEmail, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            let identifier = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identifier.isEmpty, !password.isEmpty else {
                errorMessage = "Email or username and password are required."
                return
            }

            do {
                try await session.login(identifier: identifier, password: password)
                try? biometricLoginService.save(identifier: identifier, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loginWithFaceID(using session: AppSession) async {
        errorMessage = nil
        isSubmitting = true
        defer {
            isSubmitting = false
            refreshBiometricAvailability()
        }

        do {
            let credentials = try biometricLoginService.loadCredentials()
            try await session.login(identifier: credentials.identifier, password: credentials.password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle(using session: AppSession, presenting viewController: UIViewController?) async {
        errorMessage = nil
        guard let viewController else {
            errorMessage = "Unable to present Google Sign-In."
            return
        }

        isSubmitting = true
        defer {
            isSubmitting = false
            refreshBiometricAvailability()
        }

        do {
            try await session.signInWithGoogle(presenting: viewController)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>, using session: AppSession) async {
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentAppleNonce,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign-In did not return a valid token."
                return
            }

            isSubmitting = true
            defer {
                isSubmitting = false
                currentAppleNonce = nil
                refreshBiometricAvailability()
            }

            do {
                try await session.signInWithApple(
                    idToken: idToken,
                    nonce: nonce,
                    fullName: credential.fullName,
                    email: credential.email
                )
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            currentAppleNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func isDisplayNameTaken(_ displayName: String, in session: AppSession) -> Bool {
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return session.users.contains { user in
            user.username.lowercased() == normalizedDisplayName
                || user.displayName.lowercased() == normalizedDisplayName
        }
    }

    private func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }

        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:'\",.<>?/`~\\")
        let hasSpecialCharacter = password.rangeOfCharacter(from: specialCharacters) != nil

        return hasUppercase && hasNumber && hasSpecialCharacter
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }
}
