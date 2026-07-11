import Foundation

enum FriendRequestStatus: String, CaseIterable, Identifiable {
    case pending
    case accepted
    case declined

    var id: String { rawValue }
}

struct FriendRequest: Identifiable, Hashable {
    let id: String
    let fromUserID: String
    let toUserID: String
    var status: FriendRequestStatus
    let createdDate: Date
}
