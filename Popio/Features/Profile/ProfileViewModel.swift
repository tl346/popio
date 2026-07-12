import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var username = ""
    @Published var email = ""
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var bio = ""
    @Published var instagramHandle = ""
    @Published var errorMessage: String?
    @Published var isSaving = false

    func load(from user: PopioUser?) {
        guard let user else { return }
        username = user.username
        email = user.email
        firstName = user.firstName
        lastName = user.lastName
        bio = user.bio
        instagramHandle = user.instagramHandle
    }
}
