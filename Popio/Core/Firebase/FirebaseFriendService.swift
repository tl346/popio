import FirebaseFirestore
import Foundation

struct FirebaseFriendService: FriendServicing {
    private let database: Firestore

    init(database: Firestore = .firestore()) {
        self.database = database
    }

    func fetchFriendRequests(for userID: String) async throws -> [FriendRequest] {
        async let outgoing = database.collection("friendRequests")
            .whereField("fromUserID", isEqualTo: userID)
            .getDocuments()

        async let incoming = database.collection("friendRequests")
            .whereField("toUserID", isEqualTo: userID)
            .getDocuments()

        let snapshots = try await [outgoing, incoming]
        var requestsByID: [String: FriendRequest] = [:]

        for snapshot in snapshots {
            for document in snapshot.documents {
                if let request = try? friendRequest(from: document) {
                    requestsByID[request.id] = request
                }
            }
        }

        return requestsByID.values.sorted { $0.createdDate > $1.createdDate }
    }

    func createFriendRequest(_ request: FriendRequest) async throws {
        try await database.collection("friendRequests")
            .document(request.id)
            .setData(data(from: request), merge: true)
    }

    func searchUsers(query: String) async throws -> [PopioUser] {
        []
    }

    func sendFriendRequest(to userID: String) async throws {
    }

    func acceptFriendRequest(_ requestID: String) async throws {
        try await updateStatus(requestID: requestID, status: .accepted)
    }

    func declineFriendRequest(_ requestID: String) async throws {
        try await updateStatus(requestID: requestID, status: .declined)
    }

    func removeFriend(_ userID: String) async throws {
    }

    private func updateStatus(requestID: String, status: FriendRequestStatus) async throws {
        try await database.collection("friendRequests")
            .document(requestID)
            .setData(["status": status.rawValue], merge: true)
    }

    private func friendRequest(from document: QueryDocumentSnapshot) throws -> FriendRequest {
        let data = document.data()

        guard let fromUserID = data["fromUserID"] as? String,
              let toUserID = data["toUserID"] as? String,
              let statusValue = data["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusValue),
              let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() else {
            throw FirebaseFriendServiceError.invalidFriendRequest
        }

        return FriendRequest(
            id: document.documentID,
            fromUserID: fromUserID,
            toUserID: toUserID,
            status: status,
            createdDate: createdDate
        )
    }

    private func data(from request: FriendRequest) -> [String: Any] {
        [
            "id": request.id,
            "fromUserID": request.fromUserID,
            "toUserID": request.toUserID,
            "status": request.status.rawValue,
            "createdDate": Timestamp(date: request.createdDate)
        ]
    }
}

enum FirebaseFriendServiceError: LocalizedError {
    case invalidFriendRequest

    var errorDescription: String? {
        switch self {
        case .invalidFriendRequest:
            return "A friend request could not be loaded."
        }
    }
}
