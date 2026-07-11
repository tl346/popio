import Foundation

struct PopioUser: Identifiable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var firstName: String
    var lastName: String
    var bio: String
    var email: String
    var profilePictureURL: URL?
    var profileImageData: Data?
    var isAdmin: Bool
    let createdDate: Date
}

extension PopioUser {
    static let preview = PopioUser(
        id: "user_001",
        username: "tony",
        displayName: "Tony Lee",
        firstName: "Tony",
        lastName: "Lee",
        bio: "Explorer of pop-ups, good coffee, and great people.",
        email: "tony@example.com",
        profilePictureURL: nil,
        profileImageData: nil,
        isAdmin: true,
        createdDate: .now
    )
}
