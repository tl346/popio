import GoogleSignIn
import SwiftUI
import UIKit

@main
struct PopioApp: App {
    @StateObject private var session = AppSession()

    init() {
        PopioFontRegistrar.registerFonts()
        FirebaseBootstrap.configureIfNeeded()
        UITextField.appearance().textColor = UIColor(PopioTheme.ink)
        UITextView.appearance().textColor = UIColor(PopioTheme.ink)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(session)
                .font(PopioFont.body())
                .tint(PopioTheme.accent)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
