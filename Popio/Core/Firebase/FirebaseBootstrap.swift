import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    static var isConfigured = false

    static func configureIfNeeded() {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }

        FirebaseApp.configure()
        isConfigured = true
    }
}
