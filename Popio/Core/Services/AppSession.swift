import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
final class AppSession: ObservableObject {
    static let adminEmail = "popioadmin@gmail.com"

    @Published private(set) var currentUser: PopioUser?
    @Published private(set) var users: [PopioUser]
    @Published private(set) var friendRequests: [FriendRequest]
    @Published private(set) var events: [PopioEvent]
    @Published private(set) var eventContributions: [EventContribution]
    @Published private(set) var mailboxMessages: [MailboxMessage]

    private var authenticationService: AuthenticationServicing? {
        FirebaseBootstrap.isConfigured ? FirebaseAuthenticationService() : nil
    }

    private var eventService: EventServicing? {
        FirebaseBootstrap.isConfigured ? FirebaseEventService() : nil
    }

    private var friendService: FriendServicing? {
        FirebaseBootstrap.isConfigured ? FirebaseFriendService() : nil
    }

    init() {
        let sampleUsers = [
            PopioUser.preview,
            PopioUser(
                id: "user_002",
                username: "matchamap",
                displayName: "Mika Tan",
                firstName: "Mika",
                lastName: "Tan",
                bio: "Always tracking the next great matcha cart.",
                email: "mika@example.com",
                profilePictureURL: nil,
                profileImageData: nil,
                isAdmin: false,
                blockedUserIDs: [],
                createdDate: .now
            ),
            PopioUser(
                id: "user_003",
                username: "cardtable",
                displayName: "Jordan Chen",
                firstName: "Jordan",
                lastName: "Chen",
                bio: "Collecting pop-ups, cards, and neighborhood finds.",
                email: "jordan@example.com",
                profilePictureURL: nil,
                profileImageData: nil,
                isAdmin: false,
                blockedUserIDs: [],
                createdDate: .now
            ),
            PopioUser(
                id: "user_004",
                username: "nightmarket",
                displayName: "Ari Patel",
                firstName: "Ari",
                lastName: "Patel",
                bio: "Night market regular and local food fan.",
                email: "ari@example.com",
                profilePictureURL: nil,
                profileImageData: nil,
                isAdmin: false,
                blockedUserIDs: [],
                createdDate: .now
            )
        ]

        currentUser = nil
        users = sampleUsers
        friendRequests = []
        events = PopioEvent.samples
        eventContributions = [
            EventContribution(
                id: "review_001",
                eventID: "event_matcha_001",
                type: .review,
                createdByUserID: "user_003",
                creatorUsername: "cardtable",
                text: "Line moved quickly and the strawberry matcha was worth it.",
                imageData: nil,
                imageURL: nil,
                moderationStatus: .approved,
                moderationComment: nil,
                reviewedByUserID: "user_001",
                likedUserIDs: ["user_001"],
                likedAtByUserID: ["user_001": .now],
                createdDate: .now
            )
        ]
        mailboxMessages = []
    }
}

extension AppSession {
    func restoreSession() async {
        guard let authenticationService else { return }

        do {
            guard let user = try await authenticationService.fetchCurrentUser() else { return }
            upsert(user)
            currentUser = user
            try? await loadPersistedUsers()
            try? await loadPersistedFriendRequests()
            try? await loadPersistedEvents()
            try? await loadPersistedContributions()
            try? await loadMailboxMessages()
        } catch {
            currentUser = nil
        }
    }

    func refreshRemoteData() async {
        try? await loadPersistedUsers()
        try? await loadPersistedFriendRequests()
        try? await loadPersistedEvents()
        try? await loadPersistedContributions()
        try? await loadMailboxMessages()
    }

    func refreshMailbox() async {
        try? await loadMailboxMessages()
    }

    func register(username: String, email: String, password: String, firstName: String, lastName: String) async throws {
        if let authenticationService {
            let user = try await authenticationService.register(
                username: username,
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            upsert(user)
            currentUser = user
            try? await loadPersistedUsers()
            try? await loadPersistedFriendRequests()
            try? await loadPersistedEvents()
            try? await loadMailboxMessages()
            return
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = trimmedUsername.lowercased()
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !users.contains(where: {
            $0.username.lowercased() == normalizedUsername || $0.displayName.lowercased() == normalizedUsername
        }) else {
            throw SessionError.displayNameTaken
        }

        let user = PopioUser(
            id: UUID().uuidString,
            username: normalizedUsername.isEmpty ? "newuser" : normalizedUsername,
            displayName: trimmedUsername.isEmpty ? "newuser" : trimmedUsername,
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            bio: "",
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                profilePictureURL: nil,
                profileImageData: nil,
                isAdmin: false,
                blockedUserIDs: [],
                createdDate: .now
            )
        users.append(user)
        currentUser = user
    }

    func login(identifier: String, password: String) async throws {
        if let authenticationService {
            let user = try await authenticationService.login(identifier: identifier, password: password)
            upsert(user)
            currentUser = user
            try? await loadPersistedUsers()
            try? await loadPersistedFriendRequests()
            try? await loadPersistedEvents()
            try? await loadMailboxMessages()
            return
        }

        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let user = users.first(where: {
            $0.email.lowercased() == normalizedIdentifier || $0.username.lowercased() == normalizedIdentifier
        }) else {
            throw SessionError.invalidLogin
        }

        currentUser = user
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let authenticationService else {
            throw AuthenticationServiceError.missingFirebaseConfiguration
        }

        let user = try await authenticationService.signInWithGoogle(presenting: viewController)
        upsert(user)
        currentUser = user
        try? await loadPersistedUsers()
        try? await loadPersistedFriendRequests()
        try? await loadPersistedEvents()
        try? await loadMailboxMessages()
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?, email: String?) async throws {
        guard let authenticationService else {
            throw AuthenticationServiceError.missingFirebaseConfiguration
        }

        let user = try await authenticationService.signInWithApple(
            idToken: idToken,
            nonce: nonce,
            fullName: fullName,
            email: email
        )
        upsert(user)
        currentUser = user
        try? await loadPersistedUsers()
        try? await loadPersistedFriendRequests()
        try? await loadPersistedEvents()
        try? await loadMailboxMessages()
    }

    func logout() async throws {
        if let authenticationService {
            try await authenticationService.logout()
        }

        currentUser = nil
    }

    func deleteAccount() async throws {
        guard let deletingUser = currentUser else { return }
        let userID = deletingUser.id

        if FirebaseBootstrap.isConfigured {
            try? await FirebaseImageStorageService().deleteProfileImage(userID: userID)
        }

        if let authenticationService {
            try await authenticationService.deleteAccount(userID: userID)
        }

        users.removeAll { $0.id == userID }
        friendRequests.removeAll { $0.fromUserID == userID || $0.toUserID == userID }
        events.removeAll { $0.createdByUserID == userID }
        eventContributions.removeAll { $0.createdByUserID == userID }

        events = events.map { event in
            var updatedEvent = event
            updatedEvent.likedUserIDs.remove(userID)
            updatedEvent.likedAtByUserID.removeValue(forKey: userID)
            updatedEvent.goingUserIDs.remove(userID)
            return updatedEvent
        }

        eventContributions = eventContributions.map { contribution in
            var updatedContribution = contribution
            updatedContribution.likedUserIDs.remove(userID)
            updatedContribution.likedAtByUserID.removeValue(forKey: userID)
            return updatedContribution
        }

        currentUser = nil
    }

    func updateProfile(username: String, email: String, firstName: String, lastName: String, bio: String, instagramHandle: String) async throws {
        guard var user = currentUser else { return }

        if let authenticationService {
            let updatedUser = try await authenticationService.updateProfile(
                userID: user.id,
                username: username,
                email: email,
                firstName: firstName,
                lastName: lastName,
                bio: bio,
                instagramHandle: instagramHandle
            )
            upsert(updatedUser)
            currentUser = updatedUser
            return
        }

        user.username = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        user.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        user.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        user.instagramHandle = Self.normalizedInstagramHandle(instagramHandle)
        user.displayName = Self.displayName(firstName: user.firstName, lastName: user.lastName, fallback: user.username)
        currentUser = user

        upsert(user)
    }

    func updateProfileImage(data: Data) async throws {
        guard var user = currentUser else { return }

        user.profileImageData = data
        upsert(user)
        currentUser = user

        if FirebaseBootstrap.isConfigured {
            let storageService = FirebaseImageStorageService()
            let imageURL = try await storageService.uploadProfileImage(data: data, userID: user.id)

            if let authenticationService {
                user = try await authenticationService.updateProfileImageURL(
                    userID: user.id,
                    profilePictureURL: imageURL
                )
            } else {
                user.profilePictureURL = imageURL
            }
        }

        user.profileImageData = data
        upsert(user)
        currentUser = user
    }

    private func upsert(_ user: PopioUser) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        } else {
            users.append(user)
        }
    }

    private func loadPersistedEvents() async throws {
        guard let eventService else { return }
        let persistedEvents = try await eventService.fetchEvents(
            includePending: currentUser?.isAdmin == true,
            currentUserID: currentUser?.id
        )
        let sampleEventsByID = Dictionary(uniqueKeysWithValues: PopioEvent.samples.map { ($0.id, $0) })
        let persistedIDs = Set(persistedEvents.map(\.id))
        let localOnlySamples = sampleEventsByID.values.filter { !persistedIDs.contains($0.id) }
        events = (persistedEvents + localOnlySamples).sorted { $0.eventDate < $1.eventDate }
    }

    private func loadPersistedContributions() async throws {
        guard let eventService else { return }
        let persistedContributions = try await eventService.fetchContributions(
            includePending: currentUser?.isAdmin == true,
            currentUserID: currentUser?.id
        )
        let sampleContributionsByID = Dictionary(uniqueKeysWithValues: eventContributions.map { ($0.id, $0) })
        let persistedIDs = Set(persistedContributions.map(\.id))
        let localOnlySamples = sampleContributionsByID.values.filter { !persistedIDs.contains($0.id) }
        eventContributions = (persistedContributions + localOnlySamples).sorted { $0.createdDate > $1.createdDate }
    }

    private func loadPersistedUsers() async throws {
        guard let authenticationService else { return }
        let persistedUsers = try await authenticationService.fetchUsers()
        persistedUsers.forEach { upsert($0) }
    }

    private func loadPersistedFriendRequests() async throws {
        guard let currentUser, let friendService else { return }
        friendRequests = try await friendService.fetchFriendRequests(for: currentUser.id)
    }

    private func loadMailboxMessages() async throws {
        guard let currentUser, let eventService else { return }
        mailboxMessages = try await eventService.fetchMailboxMessages(for: currentUser.id)
    }

    private static func displayName(firstName: String, lastName: String, fallback: String) -> String {
        let fullName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? fallback : fullName
    }

    private static func normalizedInstagramHandle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://www.instagram.com/", with: "")
            .replacingOccurrences(of: "https://instagram.com/", with: "")
            .replacingOccurrences(of: "http://www.instagram.com/", with: "")
            .replacingOccurrences(of: "http://instagram.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
    }
}

enum SessionError: LocalizedError {
    case invalidLogin
    case displayNameTaken
    case rejectionCommentRequired
    case notAuthenticated
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidLogin:
            return "No account was found for that email or username."
        case .displayNameTaken:
            return "That display name is already taken."
        case .rejectionCommentRequired:
            return "Add a short explanation before rejecting this pop-up."
        case .notAuthenticated:
            return "Log in again before submitting this request."
        case .serviceUnavailable:
            return "Support requests are unavailable until Firebase is configured."
        }
    }
}

extension AppSession {
    enum RelationshipState {
        case none
        case outgoingPending
        case incomingPending
        case friends
    }

    func searchUsers(query: String) -> [PopioUser] {
        guard let currentUser else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return users.filter { user in
            user.id != currentUser.id
                && !isBlocked(user.id)
                && (trimmed.isEmpty
                    || user.username.lowercased().contains(trimmed)
                    || user.displayName.lowercased().contains(trimmed))
        }
    }

    func suggestedUsers(query: String, limit: Int = 3) -> [PopioUser] {
        searchUsers(query: query)
            .filter { user in
                let state = relationshipState(with: user)
                return state != .friends && state != .incomingPending
            }
            .prefix(limit)
            .map { $0 }
    }

    func relationshipState(with user: PopioUser) -> RelationshipState {
        guard let currentUser else { return .none }
        guard !currentUser.blockedUserIDs.contains(user.id) else { return .none }

        if friendRequests.contains(where: { request in
            request.status == .accepted
                && Set([request.fromUserID, request.toUserID]) == Set([currentUser.id, user.id])
        }) {
            return .friends
        }

        if friendRequests.contains(where: { request in
            request.fromUserID == currentUser.id
                && request.toUserID == user.id
                && request.status == .pending
        }) {
            return .outgoingPending
        }

        if friendRequests.contains(where: { request in
            request.fromUserID == user.id
                && request.toUserID == currentUser.id
                && request.status == .pending
        }) {
            return .incomingPending
        }

        return .none
    }

    func sendFriendRequest(to user: PopioUser) {
        guard let currentUser else { return }
        guard !currentUser.blockedUserIDs.contains(user.id) else { return }
        guard !friendRequests.contains(where: { request in
            Set([request.fromUserID, request.toUserID]) == Set([currentUser.id, user.id])
                && request.status != .declined
        }) else { return }

        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserID: currentUser.id,
            toUserID: user.id,
            status: .pending,
            createdDate: .now
        )
        friendRequests.append(request)

        if let friendService {
            Task {
                try? await friendService.createFriendRequest(request)
            }
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) {
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else { return }
        var updatedRequests = friendRequests
        updatedRequests[index].status = .accepted
        friendRequests = updatedRequests

        if let friendService {
            Task {
                try? await friendService.acceptFriendRequest(request.id)
            }
        }
    }

    func declineFriendRequest(_ request: FriendRequest) {
        updateFriendRequest(request, status: .declined)

        if let friendService {
            Task {
                try? await friendService.declineFriendRequest(request.id)
            }
        }
    }

    func removeFriend(_ user: PopioUser) {
        guard let currentUser else { return }
        friendRequests.removeAll { request in
            request.status == .accepted
                && Set([request.fromUserID, request.toUserID]) == Set([currentUser.id, user.id])
        }
    }

    func isBlocked(_ userID: String) -> Bool {
        currentUser?.blockedUserIDs.contains(userID) == true
    }

    func blockUser(_ userID: String) {
        guard var user = currentUser, user.id != userID else { return }
        user.blockedUserIDs.insert(userID)
        currentUser = user
        upsert(user)

        friendRequests.removeAll { request in
            request.fromUserID == userID || request.toUserID == userID
        }

        if let authenticationService {
            Task {
                if let updatedUser = try? await authenticationService.updateBlockedUserIDs(
                    userID: user.id,
                    blockedUserIDs: user.blockedUserIDs
                ) {
                    upsert(updatedUser)
                    currentUser = updatedUser
                }
            }
        }
    }

    private func updateFriendRequest(_ request: FriendRequest, status: FriendRequestStatus) {
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else { return }
        var updatedRequests = friendRequests
        updatedRequests[index].status = status
        friendRequests = updatedRequests
    }
}

extension AppSession {
    struct MVPStanding: Identifiable, Hashable {
        let id: String
        let rank: Int
        let user: PopioUser
        let points: Int
        let eventLikePoints: Int
        let contributionLikePoints: Int
    }

    var approvedEvents: [PopioEvent] {
        events
            .filter { $0.moderationStatus == .approved && !$0.isArchived && !isBlocked($0.createdByUserID) }
            .sorted { $0.eventDate < $1.eventDate }
    }

    var discoveryEvents: [PopioEvent] {
        events
            .filter { event in
                guard !event.isArchived, !isBlocked(event.createdByUserID) else { return false }
                return event.moderationStatus == .approved
                    || (event.moderationStatus == .pending && event.createdByUserID == currentUser?.id)
            }
            .sorted { $0.eventDate < $1.eventDate }
    }

    var mvpLeaderboard: [MVPStanding] {
        mvpLeaderboard(in: nil)
    }

    var weeklyMVPLeaderboard: [MVPStanding] {
        mvpLeaderboard(in: Calendar.current.dateInterval(of: .weekOfYear, for: .now))
    }

    private func mvpLeaderboard(in dateInterval: DateInterval?) -> [MVPStanding] {
        let approvedEvents = events.filter { $0.moderationStatus == .approved && !isBlocked($0.createdByUserID) }
        let approvedContributions = eventContributions.filter { $0.moderationStatus == .approved && !isBlocked($0.createdByUserID) }

        let eventPoints = Dictionary(grouping: approvedEvents, by: \.createdByUserID)
            .mapValues { creatorEvents in
                creatorEvents.reduce(0) { total, event in
                    total + pointCount(from: event.likedAtByUserID, fallbackLikedUserIDs: event.likedUserIDs, fallbackDate: event.createdDate, in: dateInterval) * 10
                }
            }

        let contributionPoints = Dictionary(grouping: approvedContributions, by: \.createdByUserID)
            .mapValues { creatorContributions in
                creatorContributions.reduce(0) { total, contribution in
                    total + pointCount(from: contribution.likedAtByUserID, fallbackLikedUserIDs: contribution.likedUserIDs, fallbackDate: contribution.createdDate, in: dateInterval) * 5
                }
            }

        let sortedUsers = users.sorted { lhs, rhs in
            let lhsPoints = (eventPoints[lhs.id] ?? 0) + (contributionPoints[lhs.id] ?? 0)
            let rhsPoints = (eventPoints[rhs.id] ?? 0) + (contributionPoints[rhs.id] ?? 0)

            if lhsPoints == rhsPoints {
                return lhs.username < rhs.username
            }

            return lhsPoints > rhsPoints
        }

        return sortedUsers.enumerated().map { index, user in
            let eventLikePoints = eventPoints[user.id] ?? 0
            let contributionLikePoints = contributionPoints[user.id] ?? 0

            return MVPStanding(
                id: user.id,
                rank: index + 1,
                user: user,
                points: eventLikePoints + contributionLikePoints,
                eventLikePoints: eventLikePoints,
                contributionLikePoints: contributionLikePoints
            )
        }
    }

    private func pointCount(
        from likedAtByUserID: [String: Date],
        fallbackLikedUserIDs: Set<String>,
        fallbackDate: Date,
        in dateInterval: DateInterval?
    ) -> Int {
        guard let dateInterval else { return fallbackLikedUserIDs.count }

        if likedAtByUserID.isEmpty {
            return dateInterval.contains(fallbackDate) ? fallbackLikedUserIDs.count : 0
        }

        return fallbackLikedUserIDs
            .compactMap { likedAtByUserID[$0] }
            .filter { dateInterval.contains($0) }
            .count
    }

    func mvpStanding(for user: PopioUser?) -> MVPStanding? {
        guard let user else { return nil }
        return mvpLeaderboard.first { $0.user.id == user.id }
    }

    var pendingEventRequests: [PopioEvent] {
        events
            .filter { $0.moderationStatus == .pending }
            .sorted { $0.eventDate < $1.eventDate }
    }

    var pendingContributionRequests: [EventContribution] {
        eventContributions
            .filter { $0.moderationStatus == .pending }
            .sorted { $0.createdDate < $1.createdDate }
    }

    struct DuplicateEventCandidate: Identifiable, Hashable {
        let event: PopioEvent
        let nameSimilarity: Double
        let locationSimilarity: Double

        var id: String { event.id }

        var combinedSimilarity: Double {
            (nameSimilarity * 0.55) + (locationSimilarity * 0.45)
        }
    }

    func duplicateEventCandidate(
        title: String,
        latitude: Double,
        longitude: Double,
        excludingEventID: String? = nil
    ) -> DuplicateEventCandidate? {
        events
            .filter { $0.id != excludingEventID }
            .compactMap { event -> DuplicateEventCandidate? in
                guard let eventLatitude = event.latitude, let eventLongitude = event.longitude else { return nil }

                let candidate = DuplicateEventCandidate(
                    event: event,
                    nameSimilarity: Self.textSimilarity(title, event.title),
                    locationSimilarity: Self.locationSimilarity(
                        latitude: latitude,
                        longitude: longitude,
                        eventLatitude: eventLatitude,
                        eventLongitude: eventLongitude
                    )
                )

                guard candidate.nameSimilarity >= 0.55,
                      candidate.locationSimilarity >= 0.65,
                      candidate.combinedSimilarity >= 0.68 else {
                    return nil
                }

                return candidate
            }
            .max { $0.combinedSimilarity < $1.combinedSimilarity }
    }

    func createEvent(
        title: String,
        description: String,
        category: EventCategory,
        address: String,
        eventDate: Date,
        startTime: Date?,
        endTime: Date?,
        imageData: Data?,
        menuImageData: Data?,
        bannerFocusY: Double,
        tags: [String] = [],
        latitude: Double,
        longitude: Double
    ) async throws {
        guard let currentUser else { return }

        let eventID = UUID().uuidString
        let imageURL: URL?
        let menuImageURL: URL?

        if let imageData, FirebaseBootstrap.isConfigured {
            imageURL = try await FirebaseImageStorageService().uploadEventImage(data: imageData, eventID: eventID)
        } else {
            imageURL = nil
        }

        if let menuImageData, FirebaseBootstrap.isConfigured {
            menuImageURL = try await FirebaseImageStorageService().uploadMenuImage(data: menuImageData, eventID: eventID)
        } else {
            menuImageURL = nil
        }

        let event = PopioEvent(
            id: eventID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            eventDate: eventDate,
            startTime: startTime,
            endTime: endTime,
            createdByUserID: currentUser.id,
            creatorUsername: currentUser.username,
            imageURL: imageURL,
            imageData: imageData,
            menuImageURL: menuImageURL,
            menuImageData: menuImageData,
            bannerFocusY: bannerFocusY,
            tags: tags,
            distanceInMiles: 0,
            isApproved: false,
            moderationStatus: .pending,
            moderationComment: nil,
            reviewedByUserID: nil,
            likedUserIDs: [],
            likedAtByUserID: [:],
            goingUserIDs: [],
            createdDate: .now
        )

        if let eventService {
            try await eventService.createEvent(event)
        }

        events.insert(event, at: 0)
    }

    func reviewEvent(_ event: PopioEvent, status: EventModerationStatus, comment: String) async throws {
        guard currentUser?.isAdmin == true else { return }
        guard status == .approved || status == .rejected else { return }
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == .rejected, trimmedComment.isEmpty {
            throw SessionError.rejectionCommentRequired
        }

        var updatedEvents = events
        updatedEvents[index].moderationStatus = status
        updatedEvents[index].isApproved = status == .approved
        updatedEvents[index].moderationComment = trimmedComment.isEmpty ? nil : trimmedComment
        updatedEvents[index].reviewedByUserID = currentUser?.id

        let mailboxMessage = MailboxMessage(
            id: UUID().uuidString,
            recipientUserID: event.createdByUserID,
            eventID: event.id,
            eventTitle: event.title,
            type: status == .approved ? .eventApproved : .eventRejected,
            message: status == .approved
                ? "Your pop-up has been approved and is now visible in the community feed."
                : trimmedComment,
            isRead: false,
            createdDate: .now
        )

        if let eventService {
            try await eventService.reviewEvent(updatedEvents[index], mailboxMessage: mailboxMessage)
        }

        events = updatedEvents

        if mailboxMessage.recipientUserID == currentUser?.id {
            mailboxMessages.insert(mailboxMessage, at: 0)
        }
    }

    func updateEvent(_ event: PopioEvent) async throws {
        guard currentUser?.isAdmin == true else { return }
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        if let eventService {
            try await eventService.updateEvent(event)
        }

        events[index] = event
        events.sort { $0.eventDate < $1.eventDate }
    }

    func deleteEvent(_ event: PopioEvent) async throws {
        guard currentUser?.isAdmin == true else { return }
        let contributionIDs = eventContributions
            .filter { $0.eventID == event.id }
            .map(\.id)

        if let eventService {
            try await eventService.deleteEvent(event.id)
        }

        if FirebaseBootstrap.isConfigured {
            let storage = FirebaseImageStorageService()
            try? await storage.deleteEventImages(eventID: event.id)
            for contributionID in contributionIDs {
                try? await storage.deleteContributionImage(contributionID: contributionID)
            }
        }

        events.removeAll { $0.id == event.id }
        eventContributions.removeAll { $0.eventID == event.id }
    }

    var unreadMailboxCount: Int {
        mailboxMessages.filter { !$0.isRead }.count
    }

    func markMailboxMessageRead(_ message: MailboxMessage) {
        guard message.recipientUserID == currentUser?.id,
              let index = mailboxMessages.firstIndex(where: { $0.id == message.id }),
              !mailboxMessages[index].isRead else { return }

        mailboxMessages[index].isRead = true

        if let eventService {
            Task {
                try? await eventService.markMailboxMessageRead(message.id)
            }
        }
    }

    func approvedContributions(for event: PopioEvent, type: EventContributionType) -> [EventContribution] {
        eventContributions
            .filter {
                $0.eventID == event.id
                    && $0.type == type
                    && ($0.moderationStatus == .approved
                        || (type == .review && $0.moderationStatus == .pending))
                    && !isBlocked($0.createdByUserID)
            }
            .sorted { $0.createdDate > $1.createdDate }
    }

    func reportContent(
        targetType: UserContentReportTargetType,
        targetID: String,
        reportedUserID: String,
        reason: String,
        details: String = ""
    ) async throws {
        guard let currentUser else { throw SessionError.notAuthenticated }
        guard currentUser.id != reportedUserID else { return }

        let report = UserContentReport(
            id: UUID().uuidString,
            reporterUserID: currentUser.id,
            reportedUserID: reportedUserID,
            targetType: targetType,
            targetID: targetID,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .open,
            createdDate: .now
        )

        guard let eventService else { throw SessionError.serviceUnavailable }
        try await eventService.createReport(
            report,
            emailSubject: "Popio Report - \(targetType.rawValue)",
            emailBody: adminEmailBody(
                title: "Popio UGC Report",
                fields: [
                    ("Type", targetType.rawValue),
                    ("Target ID", targetID),
                    ("Reported User ID", reportedUserID),
                    ("Reporter", "@\(currentUser.username)"),
                    ("Reporter ID", currentUser.id),
                    ("Reporter Email", currentUser.email),
                    ("Reason", report.reason),
                    ("Details", report.details.isEmpty ? "None provided" : report.details)
                ]
            )
        )
    }

    func submitSupportRequest(type: SupportSubmissionType, message: String) async throws {
        guard let currentUser else { throw SessionError.notAuthenticated }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        let submission = SupportSubmission(
            id: UUID().uuidString,
            userID: currentUser.id,
            username: currentUser.username,
            userEmail: currentUser.email,
            type: type,
            message: trimmedMessage,
            createdDate: .now
        )

        guard let eventService else { throw SessionError.serviceUnavailable }
        try await eventService.createSupportSubmission(
            submission,
            emailSubject: "Popio \(supportTitle(for: type))",
            emailBody: adminEmailBody(
                title: "Popio \(supportTitle(for: type))",
                fields: [
                    ("Category", supportTitle(for: type)),
                    ("User", "@\(currentUser.username)"),
                    ("User ID", currentUser.id),
                    ("Email", currentUser.email),
                    ("Message", trimmedMessage)
                ]
            )
        )
    }

    private func supportTitle(for type: SupportSubmissionType) -> String {
        switch type {
        case .feedback:
            return "Submit Feedback"
        case .bug:
            return "Report Bug"
        case .contact:
            return "Contact Support"
        }
    }

    private func adminEmailBody(title: String, fields: [(String, String)]) -> String {
        let fieldText = fields
            .map { "\($0.0): \($0.1)" }
            .joined(separator: "\n")

        return """
        \(title)

        \(fieldText)

        Sent to: \(Self.adminEmail)
        Created: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }

    func submitContribution(
        for event: PopioEvent,
        type: EventContributionType,
        text: String = "",
        imageData: Data? = nil
    ) {
        guard let currentUser else { return }

        let contributionID = UUID().uuidString
        let contribution = EventContribution(
            id: contributionID,
            eventID: event.id,
            type: type,
            createdByUserID: currentUser.id,
            creatorUsername: currentUser.username,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData,
            imageURL: nil,
            moderationStatus: type == .review ? .approved : .pending,
            moderationComment: nil,
            reviewedByUserID: nil,
            likedUserIDs: [],
            likedAtByUserID: [:],
            createdDate: .now
        )

        eventContributions.insert(contribution, at: 0)

        if let eventService {
            Task {
                var persistedContribution = contribution

                if let imageData, FirebaseBootstrap.isConfigured {
                    let imageURL = try? await FirebaseImageStorageService()
                        .uploadContributionImage(data: imageData, contributionID: contributionID)
                    persistedContribution.imageURL = imageURL

                    if let index = eventContributions.firstIndex(where: { $0.id == contributionID }) {
                        eventContributions[index].imageURL = imageURL
                    }
                }

                try? await eventService.createContribution(persistedContribution)
            }
        }
    }

    func reviewContribution(_ contribution: EventContribution, status: EventModerationStatus, comment: String) {
        guard currentUser?.isAdmin == true else { return }
        guard status == .approved || status == .rejected else { return }
        guard let index = eventContributions.firstIndex(where: { $0.id == contribution.id }) else { return }

        var updatedContributions = eventContributions
        updatedContributions[index].moderationStatus = status
        updatedContributions[index].moderationComment = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
        updatedContributions[index].reviewedByUserID = currentUser?.id
        eventContributions = updatedContributions

        if let eventService {
            Task {
                try? await eventService.createContribution(updatedContributions[index])
            }
        }
    }

    func toggleLike(for contribution: EventContribution) {
        guard let currentUserID = currentUser?.id else { return }
        guard let index = eventContributions.firstIndex(where: { $0.id == contribution.id }) else { return }

        var updatedContributions = eventContributions
        if updatedContributions[index].likedUserIDs.contains(currentUserID) {
            updatedContributions[index].likedUserIDs.remove(currentUserID)
            updatedContributions[index].likedAtByUserID.removeValue(forKey: currentUserID)
        } else {
            updatedContributions[index].likedUserIDs.insert(currentUserID)
            updatedContributions[index].likedAtByUserID[currentUserID] = .now
        }
        eventContributions = updatedContributions

        if let eventService {
            let contribution = updatedContributions[index]
            Task {
                try? await eventService.createContribution(contribution)
            }
        }
    }

    func isLikedByCurrentUser(_ contribution: EventContribution) -> Bool {
        guard let currentUserID = currentUser?.id else { return false }
        return contribution.likedUserIDs.contains(currentUserID)
    }

    func toggleLike(for event: PopioEvent) {
        guard let currentUserID = currentUser?.id else { return }
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        var updatedEvents = events
        if updatedEvents[index].likedUserIDs.contains(currentUserID) {
            updatedEvents[index].likedUserIDs.remove(currentUserID)
            updatedEvents[index].likedAtByUserID.removeValue(forKey: currentUserID)
        } else {
            updatedEvents[index].likedUserIDs.insert(currentUserID)
            updatedEvents[index].likedAtByUserID[currentUserID] = .now
        }
        events = updatedEvents

        if let eventService {
            let event = updatedEvents[index]
            Task {
                try? await eventService.createEvent(event)
            }
        }
    }

    func isLikedByCurrentUser(_ event: PopioEvent) -> Bool {
        guard let currentUserID = currentUser?.id else { return false }
        return event.likedUserIDs.contains(currentUserID)
    }

    func toggleGoing(for event: PopioEvent) {
        guard let currentUserID = currentUser?.id else { return }
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }

        var updatedEvents = events
        if updatedEvents[index].goingUserIDs.contains(currentUserID) {
            updatedEvents[index].goingUserIDs.remove(currentUserID)
        } else {
            updatedEvents[index].goingUserIDs.insert(currentUserID)
        }
        events = updatedEvents

        if let eventService {
            let event = updatedEvents[index]
            Task {
                try? await eventService.createEvent(event)
            }
        }
    }

    func isGoingByCurrentUser(_ event: PopioEvent) -> Bool {
        guard let currentUserID = currentUser?.id else { return false }
        return event.goingUserIDs.contains(currentUserID)
    }

    func creator(for event: PopioEvent) -> PopioUser? {
        users.first { $0.id == event.createdByUserID }
    }

    private static func locationSimilarity(
        latitude: Double,
        longitude: Double,
        eventLatitude: Double,
        eventLongitude: Double
    ) -> Double {
        let proposedLocation = CLLocation(latitude: latitude, longitude: longitude)
        let existingLocation = CLLocation(latitude: eventLatitude, longitude: eventLongitude)
        let distanceInMeters = proposedLocation.distance(from: existingLocation)

        if distanceInMeters <= 50 {
            return 1
        }

        if distanceInMeters >= 1_000 {
            return 0
        }

        return 1 - ((distanceInMeters - 50) / 950)
    }

    private static func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsNormalized = normalizedEventName(lhs)
        let rhsNormalized = normalizedEventName(rhs)

        guard !lhsNormalized.isEmpty, !rhsNormalized.isEmpty else { return 0 }

        let lhsTokens = Set(lhsNormalized.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhsNormalized.split(separator: " ").map(String.init))
        let tokenUnion = lhsTokens.union(rhsTokens)
        let tokenScore = tokenUnion.isEmpty ? 0 : Double(lhsTokens.intersection(rhsTokens).count) / Double(tokenUnion.count)

        let editDistance = levenshteinDistance(lhsNormalized, rhsNormalized)
        let maxLength = max(lhsNormalized.count, rhsNormalized.count)
        let editScore = maxLength == 0 ? 0 : 1 - (Double(editDistance) / Double(maxLength))

        return max(tokenScore, editScore)
    }

    private static func normalizedEventName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)

        guard !lhsCharacters.isEmpty else { return rhsCharacters.count }
        guard !rhsCharacters.isEmpty else { return lhsCharacters.count }

        var previousRow = Array(0...rhsCharacters.count)
        var currentRow = Array(repeating: 0, count: rhsCharacters.count + 1)

        for lhsIndex in 1...lhsCharacters.count {
            currentRow[0] = lhsIndex

            for rhsIndex in 1...rhsCharacters.count {
                let insertionCost = currentRow[rhsIndex - 1] + 1
                let deletionCost = previousRow[rhsIndex] + 1
                let substitutionCost = previousRow[rhsIndex - 1] + (lhsCharacters[lhsIndex - 1] == rhsCharacters[rhsIndex - 1] ? 0 : 1)
                currentRow[rhsIndex] = min(insertionCost, deletionCost, substitutionCost)
            }

            previousRow = currentRow
        }

        return previousRow[rhsCharacters.count]
    }
}
