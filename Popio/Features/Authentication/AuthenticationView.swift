import AuthenticationServices
import SwiftUI
import UIKit

struct AuthenticationView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var presentingViewController: UIViewController?

    var body: some View {
        NavigationStack {
            authContent
                .background(AuthPalette.background.ignoresSafeArea())
                .toolbar {
                    if viewModel.isRegistering {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    viewModel.isRegistering = false
                                    viewModel.errorMessage = nil
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(PopioFont.custom(size: 18, weight: .bold))
                                    .foregroundStyle(AuthPalette.ink)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Back to login")
                        }
                    }
                }
                .background(ViewControllerReader { viewController in
                    presentingViewController = viewController
                })
        }
    }

    @ViewBuilder
    private var authContent: some View {
        if viewModel.isRegistering {
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                authStack
                Spacer(minLength: 10)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                authStack
                .padding(.horizontal, 30)
                .padding(.vertical, 44)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var authStack: some View {
        VStack(spacing: viewModel.isRegistering ? 14 : 28) {
            header
            form
        }
    }

    private var header: some View {
        VStack(spacing: viewModel.isRegistering ? 10 : 18) {
            AuthBrandHeader(compact: viewModel.isRegistering)

            if viewModel.isRegistering {
                VStack(spacing: 5) {
                    Text("Create your account")
                        .font(PopioFont.custom(size: 24, weight: .semibold))
                        .foregroundStyle(AuthPalette.ink)

                    Text("Join Popio and discover local pop-ups.")
                        .font(PopioFont.custom(size: 14.5, weight: .medium))
                        .foregroundStyle(AuthPalette.muted)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Discover pop-ups. Support local. Share the vibe.")
                    .font(PopioFont.custom(size: 16, weight: .medium))
                    .foregroundStyle(AuthPalette.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var form: some View {
        VStack(spacing: viewModel.isRegistering ? 11 : 15) {
            if viewModel.isRegistering {
                HStack(spacing: 10) {
                    AuthInputRow(
                        systemImage: "person.fill",
                        placeholder: "First Name",
                        text: $viewModel.firstName,
                        characterLimit: 30,
                        capitalization: .words
                    )

                    AuthInputRow(
                        systemImage: "person.fill",
                        placeholder: "Last Name",
                        text: $viewModel.lastName,
                        characterLimit: 30,
                        capitalization: .words
                    )
                }

                AuthInputRow(
                    systemImage: "person.fill",
                    placeholder: "Display Name",
                    text: $viewModel.username,
                    characterLimit: 30,
                    capitalization: .words
                )
            }

            AuthInputRow(
                systemImage: viewModel.isRegistering ? "envelope.fill" : "person.fill",
                placeholder: viewModel.isRegistering ? "Email" : "Email or username",
                text: $viewModel.email,
                isEmail: viewModel.isRegistering,
                characterLimit: viewModel.isRegistering ? 254 : nil
            )

            AuthSecureInputRow(
                systemImage: "lock.fill",
                placeholder: "Password",
                text: $viewModel.password,
                isNewPassword: viewModel.isRegistering,
                characterLimit: viewModel.isRegistering ? 128 : nil
            )

            if viewModel.isRegistering {
                AuthSecureInputRow(
                    systemImage: "lock.fill",
                    placeholder: "Confirm Password",
                    text: $viewModel.confirmPassword,
                    isNewPassword: true,
                    submitLabel: .done,
                    characterLimit: 128
                )

                Text("Use at least 8 characters with an uppercase letter, a number, and a special character.")
                    .font(PopioFont.custom(size: 10.5, weight: .medium))
                    .foregroundStyle(AuthPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -5)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(PopioFont.footnote(.semibold))
                    .foregroundStyle(PopioTheme.coral)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PopioTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
            }

            Button {
                Task {
                    await viewModel.submit(using: session)
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(viewModel.isSubmitting ? "Please wait" : viewModel.isRegistering ? "Create account" : "Log In")
                        .font(PopioFont.custom(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: viewModel.isRegistering ? 52 : 56)
            }
            .foregroundStyle(.white)
            .background(AuthPalette.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AuthPalette.primaryShadow, radius: 18, x: 0, y: 10)
            .disabled(viewModel.isSubmitting)
            .opacity(viewModel.isSubmitting ? 0.72 : 1)
            .padding(.top, viewModel.isRegistering ? 4 : 8)

            AuthDivider()
                .padding(.vertical, viewModel.isRegistering ? 0 : 2)

            HStack(spacing: 12) {
                AppleAuthButton(
                    mode: viewModel.isRegistering ? .signUp : .signIn,
                    isDisabled: viewModel.isSubmitting,
                    onRequest: viewModel.prepareAppleRequest,
                    onCompletion: { result in
                        Task {
                            await viewModel.handleAppleAuthorization(result, using: session)
                        }
                    }
                )

                Button {
                    Task {
                        await viewModel.signInWithGoogle(
                            using: session,
                            presenting: presentingViewController
                        )
                    }
                } label: {
                    SocialButtonLabel(assetImage: "googlelogo", title: "Google")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
            }

            if !viewModel.isRegistering && viewModel.canUseBiometricLogin {
                Button {
                    Task {
                        await viewModel.loginWithFaceID(using: session)
                    }
                } label: {
                    Label("Login with Face ID", systemImage: "faceid")
                        .font(PopioFont.headline(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .foregroundStyle(AuthPalette.ink)
                .background(AuthPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AuthPalette.fieldBorder, lineWidth: 1.3)
                }
                .disabled(viewModel.isSubmitting)
            }

            AuthModePrompt(isRegistering: $viewModel.isRegistering)
                .onChange(of: viewModel.isRegistering) { _, _ in
                    viewModel.refreshBiometricAvailability()
                    viewModel.errorMessage = nil
                }
        }
        .onAppear {
            viewModel.refreshBiometricAvailability()
        }
        .padding(.bottom, viewModel.isRegistering ? 0 : 18)
    }
}

private enum AuthPalette {
    static let background = LinearGradient(
        colors: [
            PopioTheme.backgroundElevated,
            PopioTheme.background
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let ink = PopioTheme.ink
    static let muted = PopioTheme.muted
    static let fieldFill = PopioTheme.surface.opacity(0.76)
    static let fieldBorder = PopioTheme.gold.opacity(0.28)
    static let accentOrange = PopioTheme.coral
    static let accentGold = PopioTheme.gold
    static let primaryShadow = PopioTheme.gold.opacity(0.26)
    static let primaryGradient = LinearGradient(
        colors: [accentOrange, accentGold],
        startPoint: .leading,
        endPoint: .trailing
    )
}

private struct AuthBrandHeader: View {
    let compact: Bool

    var body: some View {
        Image("titlelogoimage")
            .resizable()
            .scaledToFit()
            .frame(width: compact ? 300 : 360)
            .accessibilityLabel("Popio")
    }
}

private struct AuthModePrompt: View {
    @Binding var isRegistering: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(isRegistering ? "Already have an account?" : "New Here?")
                .font(PopioFont.custom(size: 14, weight: .medium))
                .foregroundStyle(AuthPalette.muted)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isRegistering.toggle()
                }
            } label: {
                Text(isRegistering ? "Sign In >" : "Create an account >")
                    .font(PopioFont.custom(size: 14, weight: .bold))
                    .foregroundStyle(AuthPalette.accentOrange)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AuthPalette.fieldBorder)
                .frame(height: 1)

            Text("or")
                .font(PopioFont.custom(size: 12, weight: .semibold))
                .foregroundStyle(AuthPalette.muted)

            Rectangle()
                .fill(AuthPalette.fieldBorder)
                .frame(height: 1)
        }
    }
}

private struct SocialButtonLabel: View {
    let systemImage: String?
    let assetImage: String?
    let title: String

    init(systemImage: String, title: String) {
        self.systemImage = systemImage
        self.assetImage = nil
        self.title = title
    }

    init(assetImage: String, title: String) {
        self.systemImage = nil
        self.assetImage = assetImage
        self.title = title
    }

    var body: some View {
        HStack(spacing: 9) {
            if let assetImage {
                Image(assetImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(PopioFont.custom(size: 17, weight: .bold))
            }

            Text(title)
                .font(PopioFont.custom(size: 14.5, weight: .semibold))
        }
        .foregroundStyle(AuthPalette.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(AuthPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AuthPalette.fieldBorder, lineWidth: 1.3)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AppleAuthButton: View {
    let mode: SignInWithAppleButton.Label
    let isDisabled: Bool
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        ZStack {
            SocialButtonLabel(systemImage: "apple.logo", title: "Apple")

            SignInWithAppleButton(mode, onRequest: onRequest, onCompletion: onCompletion)
                .signInWithAppleButtonStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .opacity(0.02)
        }
        .frame(maxWidth: .infinity)
        .disabled(isDisabled)
    }
}

private struct ViewControllerReader: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        DispatchQueue.main.async {
            onResolve(viewController)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            onResolve(uiViewController)
        }
    }
}

private struct AuthInputRow: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    var isEmail = false
    var characterLimit: Int?
    var capitalization: TextInputAutocapitalization = .never

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 17, weight: .medium))
                .foregroundStyle(AuthPalette.muted)
                .frame(width: 24)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .font(PopioFont.custom(size: 15.5, weight: .medium))
                .foregroundStyle(AuthPalette.ink)
                .keyboardType(isEmail ? .emailAddress : .default)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onChange(of: text) { _, newValue in
                    enforceCharacterLimit(newValue)
                }
        }
        .frame(minHeight: 53)
        .padding(.horizontal, 17)
        .background(AuthPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AuthPalette.fieldBorder, lineWidth: 1.3)
        }
        .accessibilityLabel(placeholder)
    }

    private func enforceCharacterLimit(_ value: String) {
        guard let characterLimit, value.count > characterLimit else { return }
        text = String(value.prefix(characterLimit))
    }
}

private struct AuthSecureInputRow: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    var isNewPassword = false
    var submitLabel: SubmitLabel = .next
    var characterLimit: Int?
    @State private var isShowingPassword = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(PopioFont.custom(size: 17, weight: .medium))
                .foregroundStyle(AuthPalette.muted)
                .frame(width: 24)
                .accessibilityHidden(true)

            Group {
                if isShowingPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(PopioFont.custom(size: 15.5, weight: .medium))
            .foregroundStyle(AuthPalette.ink)
            .textContentType(isNewPassword ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onChange(of: text) { _, newValue in
                enforceCharacterLimit(newValue)
            }

            Button {
                isShowingPassword.toggle()
            } label: {
                Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                    .font(PopioFont.custom(size: 16, weight: .semibold))
                    .foregroundStyle(AuthPalette.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isShowingPassword ? "Hide password" : "Show password")
        }
        .frame(minHeight: 53)
        .padding(.leading, 17)
        .padding(.trailing, 10)
        .background(AuthPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AuthPalette.fieldBorder, lineWidth: 1.3)
        }
        .accessibilityLabel(placeholder)
    }

    private func enforceCharacterLimit(_ value: String) {
        guard let characterLimit, value.count > characterLimit else { return }
        text = String(value.prefix(characterLimit))
    }
}
