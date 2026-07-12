import FirebaseStorage
import Foundation

struct FirebaseImageStorageService: ImageStorageServicing {
    private let storage: Storage

    init(storage: Storage = .storage()) {
        self.storage = storage
    }

    func uploadProfileImage(data: Data, userID: String) async throws -> URL {
        try await upload(data: data, path: "profileImages/\(userID).jpg")
    }

    func uploadEventImage(data: Data, eventID: String) async throws -> URL {
        try await upload(data: data, path: "eventImages/\(eventID).jpg")
    }

    func uploadMenuImage(data: Data, eventID: String) async throws -> URL {
        try await upload(data: data, path: "menuImages/\(eventID).jpg")
    }

    func uploadContributionImage(data: Data, contributionID: String) async throws -> URL {
        try await upload(data: data, path: "eventContributionImages/\(contributionID).jpg")
    }

    private func upload(data: Data, path: String) async throws -> URL {
        let reference = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await downloadURL(for: reference)
    }

    private func downloadURL(for reference: StorageReference) async throws -> URL {
        var lastError: Error?

        for attempt in 0..<3 {
            do {
                return try await reference.downloadURL()
            } catch {
                lastError = error

                if attempt < 2 {
                    try await Task.sleep(nanoseconds: 350_000_000)
                }
            }
        }

        throw lastError ?? FirebaseImageStorageError.missingDownloadURL
    }
}

enum FirebaseImageStorageError: LocalizedError {
    case missingDownloadURL

    var errorDescription: String? {
        switch self {
        case .missingDownloadURL:
            return "The uploaded image could not be found in Firebase Storage."
        }
    }
}
