import Foundation
import UIKit

protocol AuthenticationServicing {
    func fetchCurrentUser() async throws -> PopioUser?
    func fetchUsers() async throws -> [PopioUser]
    func register(username: String, email: String, password: String, firstName: String, lastName: String) async throws -> PopioUser
    func login(identifier: String, password: String) async throws -> PopioUser
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> PopioUser
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?, email: String?) async throws -> PopioUser
    func logout() async throws
    func deleteAccount(userID: String) async throws
    func updateProfile(userID: String, username: String, email: String, firstName: String, lastName: String, bio: String, instagramHandle: String) async throws -> PopioUser
    func updateBlockedUserIDs(userID: String, blockedUserIDs: Set<String>) async throws -> PopioUser
    func updateProfileImageURL(userID: String, profilePictureURL: URL) async throws -> PopioUser
}

protocol FriendServicing {
    func fetchFriendRequests(for userID: String) async throws -> [FriendRequest]
    func createFriendRequest(_ request: FriendRequest) async throws
    func searchUsers(query: String) async throws -> [PopioUser]
    func sendFriendRequest(to userID: String) async throws
    func acceptFriendRequest(_ requestID: String) async throws
    func declineFriendRequest(_ requestID: String) async throws
    func removeFriend(_ userID: String) async throws
}

protocol EventServicing {
    func fetchEvents(includePending: Bool) async throws -> [PopioEvent]
    func createEvent(_ event: PopioEvent) async throws
    func fetchContributions(includePending: Bool) async throws -> [EventContribution]
    func createContribution(_ contribution: EventContribution) async throws
    func createReport(_ report: UserContentReport) async throws
}

protocol ImageStorageServicing {
    func uploadProfileImage(data: Data, userID: String) async throws -> URL
    func uploadEventImage(data: Data, eventID: String) async throws -> URL
    func uploadMenuImage(data: Data, eventID: String) async throws -> URL
    func uploadContributionImage(data: Data, contributionID: String) async throws -> URL
    func deleteProfileImage(userID: String) async throws
    func deleteEventImages(eventID: String) async throws
    func deleteContributionImage(contributionID: String) async throws
}
