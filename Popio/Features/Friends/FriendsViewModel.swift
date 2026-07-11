import Combine
import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var searchText = ""

    func pendingIncomingRequests(in session: AppSession) -> [FriendRequest] {
        guard let currentUserID = session.currentUser?.id else { return [] }
        return session.friendRequests.filter {
            $0.toUserID == currentUserID && $0.status == .pending
        }
    }

    func friends(in session: AppSession) -> [PopioUser] {
        guard let currentUserID = session.currentUser?.id else { return [] }

        let friendIDs = Set(session.friendRequests.compactMap { request -> String? in
            guard request.status == .accepted else { return nil }
            if request.fromUserID == currentUserID { return request.toUserID }
            if request.toUserID == currentUserID { return request.fromUserID }
            return nil
        })

        return session.users.filter { friendIDs.contains($0.id) }
    }
}
