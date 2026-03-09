import SwiftUI
import UIKit
import AuthenticationServices

private enum AuthScreen {
    case login
    case signup
    case forgotPassword
}

private enum AuthBackgroundStyle {
    case login
    case signup
    case forgot
}

private enum AuthFieldValidationState {
    case neutral
    case valid
    case invalid
}

private enum AuthSocialProvider {
    case google
    case apple

    var title: String {
        switch self {
        case .google: return "Continue with Google"
        case .apple: return "Continue with Apple"
        }
    }

    var iconSystemName: String {
        switch self {
        case .google: return "globe"
        case .apple: return "applelogo"
        }
    }
}

struct AuthFlowView: View {
    @EnvironmentObject private var session: AppSessionStore
    @State private var currentScreen: AuthScreen = .login

    var body: some View {
        ZStack {
            authBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                #if DEBUG
                authDebugBanner
                #endif

                Group {
                    switch currentScreen {
                    case .login:
                        LoginScreen(
                            onSignUp: { currentScreen = .signup },
                            onForgotPassword: { currentScreen = .forgotPassword }
                        )
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    case .signup:
                        SignUpScreen(
                            onSignIn: { currentScreen = .login }
                        )
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    case .forgotPassword:
                        ForgotPasswordScreen(
                            onBackToLogin: { currentScreen = .login }
                        )
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    }
                }
            }
        }
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: currentScreen)
        .ignoresSafeArea(.container, edges: [.bottom])
        .task {
            await session.refreshBackendReachability()
        }
    }

    private var authBackground: some View {
        AuthBackgroundView(
            style: {
                switch currentScreen {
                case .login: return .login
                case .signup: return .signup
                case .forgotPassword: return .forgot
                }
            }()
        )
    }

    private var authDebugBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.backendReachable ? Color.green : FriendZoneTheme.Colors.error)
                .frame(width: 8, height: 8)

            Text("API \(session.backendReachable ? "reachable" : "unreachable")")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                .foregroundColor(FriendZoneTheme.Colors.textPrimary)

            Text(AppConfig.baseURL.absoluteString)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("DBG-0310")
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .bold))
                .foregroundColor(FriendZoneTheme.Colors.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.84))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 1)
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
    }
}

private struct AuthLayout<Content: View>: View {
    let titlePrefix: String
    let titleHighlight: String
    let subtitle: String
    let content: Content

    init(
        titlePrefix: String,
        titleHighlight: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titlePrefix = titlePrefix
        self.titleHighlight = titleHighlight
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    hero
                    card
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 20)
                .padding(.top, max(20, proxy.safeAreaInsets.top))
                .padding(.bottom, max(20, proxy.safeAreaInsets.bottom))
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            FriendZoneBrandPill()

            (
                Text(titlePrefix)
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                + Text(titleHighlight)
                    .foregroundColor(FriendZoneTheme.Colors.primary)
            )
            .font(FriendZoneTheme.Typography.displaySerif(34, weight: .bold))
            .lineSpacing(1)
            .padding(.top, 14)

            Text(subtitle)
                .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var card: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(18)
        .background(Color.white.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FriendZoneTheme.Colors.borderSubtle, lineWidth: 2)
        }
        .friendZoneShadow(FriendZoneTheme.Shadows.lg)
    }

}

private struct LoginScreen: View {
    @EnvironmentObject private var session: AppSessionStore
    let onSignUp: () -> Void
    let onForgotPassword: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    var body: some View {
        AuthLayout(
            titlePrefix: "Welcome ",
            titleHighlight: "back",
            subtitle: "Sign in to discover what is happening nearby."
        ) {
            VStack(spacing: 12) {
                AuthLineInputRow(
                    icon: "person.crop.circle",
                    placeholder: "Username",
                    text: $username,
                    contentType: .username
                )

                AuthLineInputRow(
                    icon: "lock",
                    placeholder: "Password",
                    text: $password,
                    secure: true,
                    contentType: .password
                )

                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        onForgotPassword()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .buttonStyle(.plain)
                }
                .padding(.top, -2)

                if !errorMessage.isEmpty {
                    errorBanner(errorMessage)
                }

                Button {
                    submit()
                } label: {
                    Text(isSubmitting ? "Signing in..." : "Sign in")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.55)
                .padding(.top, 6)

                authDivider("or continue with")

                Button {
                    errorMessage = "Google sign-in backend is ready, but this iOS build still needs the native Google SDK flow."
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Text("Do not have an account?")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Sign up") {
                        onSignUp()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            }
        }
        .onChange(of: username) { newValue in
            let filtered = newValue.lowercased().filter { char in
                char.isLowercase || char.isNumber || char == "_"
            }
            if filtered != newValue {
                username = filtered
            }
        }
    }

    private var canSubmit: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
            !password.isEmpty &&
            !isSubmitting
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = ""
        isSubmitting = true
        Task {
            do {
                try await session.login(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await MainActor.run {
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "\(error.localizedDescription)\nAPI: \(AppConfig.baseURL.absoluteString)"
                }
            }
        }
    }
}

private struct SignUpScreen: View {
    @EnvironmentObject private var session: AppSessionStore
    let onSignIn: () -> Void

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isSubmitting = false
    @State private var isSocialSubmitting = false
    @State private var errorMessage = ""
    @State private var backendErrors: [String: String] = [:]
    private let appleSignInCoordinator = AppleSignInCoordinator.shared
    private let googleSignInCoordinator = GoogleSignInCoordinator.shared

    var body: some View {
        AuthLayout(
            titlePrefix: "Create your ",
            titleHighlight: "account",
            subtitle: "Join hangouts nearby in less than a minute."
        ) {
            VStack(spacing: 8) {
                AuthProviderButton(
                    provider: .google,
                    isLoading: isSocialSubmitting
                ) {
                    submitSocial(.google)
                }

                AuthProviderButton(
                    provider: .apple,
                    isLoading: isSocialSubmitting
                ) {
                    submitSocial(.apple)
                }

                authDivider("or sign up with email")

                AuthLineInputRow(
                    icon: "person.crop.circle",
                    placeholder: "Username",
                    text: $username,
                    secure: false,
                    contentType: .username,
                    hasError: backendErrors["username"] != nil,
                    validationState: usernameValidationState
                )
                if let backendError = backendErrors["username"] {
                    validationHint(backendError)
                } else if !username.isEmpty && !usernameValid {
                    validationHint("Use 3-20 letters, numbers, or _")
                }

                AuthLineInputRow(
                    icon: "envelope",
                    placeholder: "Email",
                    text: $email,
                    secure: false,
                    keyboardType: .emailAddress,
                    contentType: .emailAddress,
                    hasError: backendErrors["email"] != nil,
                    validationState: emailValidationState
                )
                if let backendError = backendErrors["email"] {
                    validationHint(backendError)
                } else if !email.isEmpty && !emailValid {
                    validationHint("Enter a valid email address")
                }

                AuthLineInputRow(
                    icon: "lock",
                    placeholder: "Password (min. 8 chars)",
                    text: $password,
                    secure: true,
                    contentType: .newPassword,
                    hasError: backendErrors["password1"] != nil,
                    validationState: passwordValidationState
                )
                if let backendError = backendErrors["password1"] {
                    validationHint(backendError)
                } else if !password.isEmpty && !passwordValid {
                    validationHint("Password must be at least 8 characters")
                }

                AuthLineInputRow(
                    icon: "lock.shield",
                    placeholder: "Confirm password",
                    text: $passwordConfirm,
                    secure: true,
                    contentType: .newPassword,
                    hasError: backendErrors["password2"] != nil,
                    validationState: passwordMatchValidationState
                )
                if let backendError = backendErrors["password2"] {
                    validationHint(backendError)
                } else if !passwordConfirm.isEmpty && !passwordMatch {
                    validationHint("Passwords do not match")
                }

                if !errorMessage.isEmpty {
                    errorBanner(errorMessage)
                        .padding(.top, 4)
                }

                Button {
                    submit()
                } label: {
                    Text(isSubmitting ? "Creating account..." : "Create account")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.55)
                .padding(.top, 10)

                HStack(spacing: 6) {
                    Text("Already have an account?")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                    Button("Sign in") {
                        onSignIn()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            }
        }
        .onChange(of: username) { newValue in
            let filtered = newValue.lowercased().filter { char in
                char.isLowercase || char.isNumber || char == "_"
            }
            if filtered != newValue {
                username = filtered
            }
            clearBackendError("username")
        }
        .onChange(of: email) { _ in clearBackendError("email") }
        .onChange(of: password) { _ in clearBackendError("password1") }
        .onChange(of: passwordConfirm) { _ in clearBackendError("password2") }
    }

    private var usernameValid: Bool {
        let regex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: username)
    }

    private var emailValid: Bool {
        let regex = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    private var passwordValid: Bool {
        password.count >= 8
    }

    private var passwordMatch: Bool {
        !password.isEmpty && password == passwordConfirm
    }

    private var canSubmit: Bool {
        usernameValid && emailValid && passwordValid && passwordMatch && !isSubmitting && !isSocialSubmitting
    }

    private var usernameValidationState: AuthFieldValidationState {
        username.isEmpty ? .neutral : (usernameValid ? .valid : .invalid)
    }

    private var emailValidationState: AuthFieldValidationState {
        email.isEmpty ? .neutral : (emailValid ? .valid : .invalid)
    }

    private var passwordValidationState: AuthFieldValidationState {
        password.isEmpty ? .neutral : (passwordValid ? .valid : .invalid)
    }

    private var passwordMatchValidationState: AuthFieldValidationState {
        passwordConfirm.isEmpty ? .neutral : (passwordMatch ? .valid : .invalid)
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = ""
        backendErrors = [:]
        isSubmitting = true
        Task {
            do {
                try await session.register(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    passwordConfirmation: passwordConfirm
                )
                await MainActor.run {
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "\(error.localizedDescription)\nAPI: \(AppConfig.baseURL.absoluteString)"
                }
            }
        }
    }

    private func submitSocial(_ provider: AuthSocialProvider) {
        guard !isSocialSubmitting && !isSubmitting else { return }
        errorMessage = ""
        backendErrors = [:]
        switch provider {
        case .google:
            isSocialSubmitting = true
            Task {
                do {
                    let credential = try await googleSignInCoordinator.signIn()
                    try await session.loginWithGoogle(
                        authorizationCode: credential.authorizationCode,
                        redirectURI: credential.redirectURI
                    )
                    await MainActor.run {
                        isSocialSubmitting = false
                    }
                } catch {
                    await MainActor.run {
                        isSocialSubmitting = false
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            return
                        }
                        errorMessage = "\(error.localizedDescription)\nAPI: \(AppConfig.baseURL.absoluteString)"
                    }
                }
            }
        case .apple:
            isSocialSubmitting = true
            Task {
                do {
                    let credential = try await appleSignInCoordinator.signIn()
                    try await session.loginWithApple(
                        authorizationCode: credential.authorizationCode,
                        identityToken: credential.identityToken
                    )
                    await MainActor.run {
                        isSocialSubmitting = false
                    }
                } catch {
                    await MainActor.run {
                        isSocialSubmitting = false
                        if let authError = error as? ASAuthorizationError,
                           authError.code == .canceled {
                            return
                        }
                        errorMessage = "\(error.localizedDescription)\nAPI: \(AppConfig.baseURL.absoluteString)"
                    }
                }
            }
        }
    }

    private func clearBackendError(_ key: String) {
        if backendErrors[key] != nil {
            backendErrors[key] = nil
        }
    }
}

private struct AppleSignInPayload {
    let authorizationCode: String
    let identityToken: String?
}

private struct GoogleSignInPayload {
    let authorizationCode: String
    let redirectURI: String
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInCoordinator()

    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?

    @MainActor
    func signIn() async throws -> AppleSignInPayload {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let authorizationCode = String(data: codeData, encoding: .utf8) else {
            continuation?.resume(throwing: AppSessionError.invalidResponse)
            continuation = nil
            return
        }

        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        continuation?.resume(
            returning: AppleSignInPayload(
                authorizationCode: authorizationCode,
                identityToken: identityToken
            )
        )
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private final class GoogleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleSignInCoordinator()

    @MainActor
    func signIn() async throws -> GoogleSignInPayload {
        guard let clientID = AppConfig.googleClientID,
              let redirectURI = AppConfig.googleRedirectURI,
              let redirectScheme = AppConfig.googleRedirectScheme else {
            throw AppSessionError.httpStatus(500, "Missing Google client configuration in this build.")
        }

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "access_type", value: "offline"),
        ]

        guard let authURL = components?.url else {
            throw AppSessionError.invalidResponse
        }

        let callbackURL = try await startSession(url: authURL, callbackScheme: redirectScheme)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            throw AppSessionError.httpStatus(400, "Google did not return an authorization code.")
        }

        return GoogleSignInPayload(authorizationCode: code, redirectURI: redirectURI)
    }

    @MainActor
    private func startSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                Self.releaseAllSessions()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: AppSessionError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
            Self.retain(session)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private static var retainedSessions: [ASWebAuthenticationSession] = []

    private static func retain(_ session: ASWebAuthenticationSession) {
        retainedSessions.append(session)
    }

    private static func releaseAllSessions() {
        retainedSessions.removeAll()
    }
}

private struct ForgotPasswordScreen: View {
    @EnvironmentObject private var session: AppSessionStore
    let onBackToLogin: () -> Void

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var didSend = false
    @State private var errorMessage = ""

    var body: some View {
        AuthLayout(
            titlePrefix: didSend ? "Check your " : "Reset your ",
            titleHighlight: didSend ? "email" : "password",
            subtitle: didSend
                ? "If your account exists, you will receive reset instructions shortly."
                : "Enter your email and we will send you a reset link."
        ) {
            if didSend {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sent to \(email)")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.textPrimary)

                    Text("Check spam if you do not see the message.")
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
                        .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        .padding(.bottom, 6)

                    Button("Back to login") {
                        onBackToLogin()
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)

                    Button("Resend email") {
                        didSend = false
                        errorMessage = ""
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                    .foregroundColor(FriendZoneTheme.Colors.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 12) {
                    AuthLineInputRow(
                        icon: "envelope",
                        placeholder: "Email",
                        text: $email,
                        secure: false,
                        keyboardType: .emailAddress,
                        contentType: .emailAddress,
                        hasError: !errorMessage.isEmpty
                    )

                    if !errorMessage.isEmpty {
                        errorBanner(errorMessage)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(isSubmitting ? "Sending..." : "Send reset link")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [FriendZoneTheme.Colors.primary, Color(hex: "#7C3AED")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)

                    HStack(spacing: 6) {
                        Text("Remembered your password?")
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
                            .foregroundColor(FriendZoneTheme.Colors.textSecondary)
                        Button("Back to login") {
                            onBackToLogin()
                        }
                        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
                        .foregroundColor(FriendZoneTheme.Colors.primary)
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    private func submit() {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        errorMessage = ""
        isSubmitting = true
        Task {
            do {
                try await session.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    isSubmitting = false
                    didSend = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "\(error.localizedDescription)\nAPI: \(AppConfig.baseURL.absoluteString)"
                }
            }
        }
    }
}

private struct AuthLineInputRow: View {
    let icon: String?
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var hasError: Bool = false
    var validationState: AuthFieldValidationState = .neutral

    @FocusState private var isFocused: Bool
    @State private var isPulsing = false

    private var showsFloatingLabel: Bool {
        isFocused || !text.isEmpty
    }

    private var tintColor: Color {
        if hasError || validationState == .invalid {
            return FriendZoneTheme.Colors.error
        }
        if isFocused {
            return FriendZoneTheme.Colors.primary
        }
        return FriendZoneTheme.Colors.primary.opacity(0.52)
    }

    private var labelColor: Color {
        if hasError || validationState == .invalid {
            return FriendZoneTheme.Colors.error.opacity(0.90)
        }
        return isFocused ? FriendZoneTheme.Colors.primary : FriendZoneTheme.Colors.textTertiary
    }

    private var iconColor: Color {
        if hasError || validationState == .invalid {
            return FriendZoneTheme.Colors.error.opacity(0.8)
        }
        if isFocused {
            return FriendZoneTheme.Colors.primary
        }
        return FriendZoneTheme.Colors.textTertiary
    }

    private var lineProgress: CGFloat {
        if hasError || validationState == .invalid {
            return 1
        }
        if isFocused {
            return 1
        }
        if text.isEmpty {
            return 0.12
        }
        return 0.44
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }

                ZStack(alignment: .leading) {
                    if showsFloatingLabel {
                        Text(placeholder)
                            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .semibold))
                            .foregroundColor(labelColor)
                            .offset(y: -16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Group {
                        if secure {
                            SecureField(showsFloatingLabel ? "" : placeholder, text: $text)
                        } else {
                            TextField(showsFloatingLabel ? "" : placeholder, text: $text)
                        }
                    }
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeBase, weight: .regular))
                    .keyboardType(keyboardType)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .offset(y: showsFloatingLabel ? 6 : 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)

                if validationState != .neutral {
                    Image(systemName: validationState == .valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(validationState == .valid ? Color(hex: "#30D158") : FriendZoneTheme.Colors.error.opacity(0.8))
                }
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FriendZoneTheme.Colors.borderSubtle)
                    .frame(height: 1)

                GeometryReader { proxy in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(isPulsing ? 0.52 : 0.78),
                                    tintColor,
                                    tintColor.opacity(isPulsing ? 0.78 : 0.52)
                                ],
                                startPoint: isPulsing ? .leading : .trailing,
                                endPoint: isPulsing ? .trailing : .leading
                            )
                        )
                        .frame(width: max(proxy.size.width * lineProgress, 10), height: isFocused ? 2.5 : 1.5)
                        .shadow(color: tintColor.opacity(isFocused ? 0.24 : 0), radius: isFocused ? 6 : 0, y: 0)
                        .animation(FriendZoneTheme.Motion.easeOutExpo, value: lineProgress)
                }
                .frame(height: 3)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
        .animation(FriendZoneTheme.Motion.easeOutExpo, value: showsFloatingLabel)
        .onAppear {
            isPulsing = false
        }
        .onChange(of: isFocused) { focused in
            if focused {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPulsing = false
                }
            }
        }
    }
}

private struct AuthProviderButton: View {
    let provider: AuthSocialProvider
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: provider.iconSystemName)
                    .font(.system(size: 15, weight: .semibold))
                Text(isLoading ? "Connecting..." : provider.title)
                    .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .semibold))
            }
            .foregroundColor(FriendZoneTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white.opacity(0.7))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(FriendZoneTheme.Colors.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.65 : 1)
    }
}

private struct AuthBackgroundView: View {
    let style: AuthBackgroundStyle

    private var topBubbleOffset: CGPoint {
        switch style {
        case .login: return CGPoint(x: -155, y: -288)
        case .signup: return CGPoint(x: 150, y: -288)
        case .forgot: return CGPoint(x: -148, y: -282)
        }
    }

    private var bottomBubbleOffset: CGPoint {
        switch style {
        case .login: return CGPoint(x: 150, y: 300)
        case .signup: return CGPoint(x: -145, y: 302)
        case .forgot: return CGPoint(x: 145, y: 296)
        }
    }

    var body: some View {
        ZStack {
            FriendZoneTheme.Colors.background

            Circle()
                .fill(FriendZoneTheme.Colors.primary.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 42)
                .offset(x: topBubbleOffset.x, y: topBubbleOffset.y)

            Circle()
                .fill(FriendZoneTheme.Colors.primaryAccent.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: bottomBubbleOffset.x, y: bottomBubbleOffset.y)
        }
    }
}

private func validationHint(_ message: String) -> some View {
    Text(message)
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
        .foregroundColor(FriendZoneTheme.Colors.error)
        .frame(maxWidth: .infinity, alignment: .leading)
}

private func errorBanner(_ message: String) -> some View {
    Text(message)
        .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeSM, weight: .medium))
        .foregroundColor(FriendZoneTokens.Colors.errorStrong)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 42)
        .background(FriendZoneTheme.Colors.error.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FriendZoneTheme.Colors.error.opacity(0.24), lineWidth: 1)
        }
}

private func authDivider(_ text: String) -> some View {
    HStack(spacing: 12) {
        Rectangle()
            .fill(FriendZoneTheme.Colors.borderSubtle)
            .frame(height: 1)
        Text(text)
            .font(FriendZoneTheme.Typography.system(FriendZoneTheme.Typography.sizeXS, weight: .medium))
            .foregroundColor(FriendZoneTheme.Colors.textTertiary)
        Rectangle()
            .fill(FriendZoneTheme.Colors.borderSubtle)
            .frame(height: 1)
    }
    .padding(.top, 14)
    .padding(.bottom, 10)
}
