import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn
import UIKit

struct FirebaseAuthenticationService: AuthenticationServicing {
    private let auth: Auth
    private let database: Firestore

    init(auth: Auth = .auth(), database: Firestore = .firestore()) {
        self.auth = auth
        self.database = database
    }

    func fetchCurrentUser() async throws -> PopioUser? {
        guard let userID = auth.currentUser?.uid else { return nil }
        return try await fetchUser(userID: userID)
    }

    func fetchUsers() async throws -> [PopioUser] {
        let snapshot = try await database.collection("users").getDocuments()
        return snapshot.documents.compactMap { document in
            try? user(from: document.documentID, data: document.data())
        }
    }

    func register(username: String, email: String, password: String, firstName: String, lastName: String) async throws -> PopioUser {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = trimmedUsername.lowercased()
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        let usernameSnapshot = try await database.collection("users")
            .whereField("username", isEqualTo: normalizedUsername)
            .limit(to: 1)
            .getDocuments()

        guard usernameSnapshot.documents.isEmpty else {
            throw AuthenticationServiceError.usernameTaken
        }

        let result = try await auth.createUser(withEmail: normalizedEmail, password: password)
        let user = PopioUser(
            id: result.user.uid,
            username: normalizedUsername,
            displayName: trimmedUsername,
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            bio: "",
            email: normalizedEmail,
            profilePictureURL: nil,
            profileImageData: nil,
            isAdmin: false,
            createdDate: .now
        )

        try await save(user)
        return user
    }

    func updateProfileImageURL(userID: String, profilePictureURL: URL) async throws -> PopioUser {
        var user = try await fetchUser(userID: userID)
        user.profilePictureURL = profilePictureURL
        try await save(user)
        return user
    }

    func login(identifier: String, password: String) async throws -> PopioUser {
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedEmail: String

        if normalizedIdentifier.contains("@") {
            normalizedEmail = normalizedIdentifier
        } else {
            let usernameSnapshot = try await database.collection("users")
                .whereField("username", isEqualTo: normalizedIdentifier)
                .limit(to: 1)
                .getDocuments()

            guard let email = usernameSnapshot.documents.first?.data()["email"] as? String else {
                throw AuthenticationServiceError.missingUserProfile
            }

            normalizedEmail = email
        }

        let result = try await auth.signIn(withEmail: normalizedEmail, password: password)
        return try await fetchUser(userID: result.user.uid)
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> PopioUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationServiceError.missingGoogleClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        let googleUser = result.user

        guard let idToken = googleUser.idToken?.tokenString else {
            throw AuthenticationServiceError.missingIdentityToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )
        let authResult = try await auth.signIn(with: credential)
        return try await fetchOrCreateOAuthUser(
            firebaseUser: authResult.user,
            email: authResult.user.email ?? googleUser.profile?.email,
            displayName: googleUser.profile?.name ?? authResult.user.displayName,
            firstName: googleUser.profile?.givenName ?? "",
            lastName: googleUser.profile?.familyName ?? "",
            profilePictureURL: googleUser.profile?.imageURL(withDimension: 240)
        )
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?, email: String?) async throws -> PopioUser {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )
        let authResult = try await auth.signIn(with: credential)
        let firstName = fullName?.givenName ?? ""
        let lastName = fullName?.familyName ?? ""
        return try await fetchOrCreateOAuthUser(
            firebaseUser: authResult.user,
            email: email ?? authResult.user.email,
            displayName: authResult.user.displayName,
            firstName: firstName,
            lastName: lastName,
            profilePictureURL: nil
        )
    }

    func logout() async throws {
        try auth.signOut()
    }

    func updateProfile(userID: String, username: String, email: String, firstName: String, lastName: String, bio: String, instagramHandle: String) async throws -> PopioUser {
        var user = try await fetchUser(userID: userID)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedUsername != user.username {
            let usernameSnapshot = try await database.collection("users")
                .whereField("username", isEqualTo: normalizedUsername)
                .limit(to: 1)
                .getDocuments()

            let usernameBelongsToCurrentUser = usernameSnapshot.documents.first?.documentID == userID
            guard usernameSnapshot.documents.isEmpty || usernameBelongsToCurrentUser else {
                throw AuthenticationServiceError.usernameTaken
            }
        }

        if auth.currentUser?.uid == userID, normalizedEmail != user.email {
            try await auth.currentUser?.updateEmail(to: normalizedEmail)
        }

        user.username = normalizedUsername
        user.email = normalizedEmail
        user.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        user.instagramHandle = normalizedInstagramHandle(instagramHandle)
        user.displayName = displayName(firstName: user.firstName, lastName: user.lastName, fallback: user.username)
        try await save(user)
        return user
    }

    private func fetchUser(userID: String) async throws -> PopioUser {
        let snapshot = try await database.collection("users").document(userID).getDocument()

        guard let data = snapshot.data() else {
            throw AuthenticationServiceError.missingUserProfile
        }

        return try user(from: userID, data: data)
    }

    private func fetchOrCreateOAuthUser(
        firebaseUser: User,
        email: String?,
        displayName: String?,
        firstName: String,
        lastName: String,
        profilePictureURL: URL?
    ) async throws -> PopioUser {
        if let existingUser = try? await fetchUser(userID: firebaseUser.uid) {
            return existingUser
        }

        let normalizedEmail = (email ?? firebaseUser.email ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let resolvedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = try await uniqueUsername(
            preferredName: fallbackName,
            email: normalizedEmail,
            userID: firebaseUser.uid
        )
        let resolvedDisplayName = self.displayName(
            firstName: resolvedFirstName,
            lastName: resolvedLastName,
            fallback: fallbackName?.isEmpty == false ? fallbackName! : username
        )

        let user = PopioUser(
            id: firebaseUser.uid,
            username: username,
            displayName: resolvedDisplayName,
            firstName: resolvedFirstName,
            lastName: resolvedLastName,
            bio: "",
            email: normalizedEmail,
            profilePictureURL: profilePictureURL,
            profileImageData: nil,
            isAdmin: false,
            createdDate: .now
        )

        try await save(user)
        return user
    }

    private func uniqueUsername(preferredName: String?, email: String, userID: String) async throws -> String {
        let baseCandidate: String
        if let preferredName, !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseCandidate = preferredName
        } else if let emailPrefix = email.split(separator: "@").first, !emailPrefix.isEmpty {
            baseCandidate = String(emailPrefix)
        } else {
            baseCandidate = "popio"
        }

        let sanitizedBase = baseCandidate
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()

        let base = sanitizedBase.isEmpty ? "popio" : sanitizedBase
        var candidate = base
        var suffix = 1

        while try await isUsernameTaken(candidate, excludingUserID: userID) {
            suffix += 1
            candidate = "\(base)\(suffix)"
        }

        return candidate
    }

    private func isUsernameTaken(_ username: String, excludingUserID: String) async throws -> Bool {
        let snapshot = try await database.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else { return false }
        return document.documentID != excludingUserID
    }

    private func user(from userID: String, data: [String: Any]) throws -> PopioUser {
        guard let username = data["username"] as? String,
              let displayName = data["displayName"] as? String,
              let email = data["email"] as? String else {
            throw AuthenticationServiceError.missingUserProfile
        }

        let profilePictureURL = (data["profilePictureURL"] as? String).flatMap(URL.init(string:))
        let firstName = data["firstName"] as? String ?? ""
        let lastName = data["lastName"] as? String ?? ""
        let bio = data["bio"] as? String ?? ""
        let instagramHandle = data["instagramHandle"] as? String ?? ""
        let isAdmin = data["isAdmin"] as? Bool ?? false
        let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() ?? .now

        return PopioUser(
            id: userID,
            username: username,
            displayName: displayName,
            firstName: firstName,
            lastName: lastName,
            bio: bio,
            instagramHandle: instagramHandle,
            email: email,
            profilePictureURL: profilePictureURL,
            profileImageData: nil,
            isAdmin: isAdmin,
            createdDate: createdDate
        )
    }

    private func save(_ user: PopioUser) async throws {
        var data: [String: Any] = [
            "id": user.id,
            "username": user.username,
            "displayName": user.displayName,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "bio": user.bio,
            "instagramHandle": user.instagramHandle,
            "email": user.email,
            "isAdmin": user.isAdmin,
            "createdDate": Timestamp(date: user.createdDate)
        ]

        if let profilePictureURL = user.profilePictureURL {
            data["profilePictureURL"] = profilePictureURL.absoluteString
        }

        try await database.collection("users").document(user.id).setData(data, merge: true)
    }

    private func displayName(firstName: String, lastName: String, fallback: String) -> String {
        let fullName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? fallback : fullName
    }

    private func normalizedInstagramHandle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://www.instagram.com/", with: "")
            .replacingOccurrences(of: "https://instagram.com/", with: "")
            .replacingOccurrences(of: "http://www.instagram.com/", with: "")
            .replacingOccurrences(of: "http://instagram.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
    }
}

enum AuthenticationServiceError: LocalizedError {
    case missingFirebaseConfiguration
    case missingGoogleClientID
    case missingIdentityToken
    case missingUserProfile
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .missingFirebaseConfiguration:
            return "Firebase is not configured. Add GoogleService-Info.plist to the app target."
        case .missingGoogleClientID:
            return "Google Sign-In is not configured. Download a new GoogleService-Info.plist after enabling Google sign-in in Firebase."
        case .missingIdentityToken:
            return "The identity provider did not return a valid sign-in token."
        case .missingUserProfile:
            return "No Popio profile was found for this account."
        case .usernameTaken:
            return "That display name is already taken."
        }
    }
}
