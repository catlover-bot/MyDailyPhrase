import Foundation
import Combine
import Domain
import Presentation

@MainActor
final class AppAuthViewModel: ObservableObject {
    enum EntryScreen {
        case welcome
        case login
        case register
        case setup
    }

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentFeatureAccess: FeatureAccessSnapshot = .signedOutDefault
    @Published private(set) var isBusy: Bool = false
    @Published var entryScreen: EntryScreen = .welcome
    @Published var pendingDisplayName: String = ""
    @Published var inlineMessage: String? = nil
    @Published private(set) var lastAuthErrorDescription: String? = nil

    private let authRepository: AuthRepository
    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
    private let authEnabledValue: Bool
    private let signInWithAppleEnabledValue: Bool
    private let googleSignInEnabledValue: Bool
    private let guestModeEnabledValue: Bool
    private let adminMenuEnabledValue: Bool
    private let safeModeEnabledValue: Bool
    private let termsOfServiceURLValue: URL?
    private let privacyPolicyURLValue: URL?
    private let loadPersistedAuthError: @Sendable () -> String?
    private var creatorPassEntitled: Bool = false

    init(
        authRepository: AuthRepository,
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase,
        authEnabled: Bool,
        signInWithAppleEnabled: Bool,
        googleSignInEnabled: Bool,
        guestModeEnabled: Bool,
        adminMenuEnabled: Bool,
        safeModeEnabled: Bool = false,
        termsOfServiceURL: URL?,
        privacyPolicyURL: URL?,
        loadPersistedAuthError: @escaping @Sendable () -> String?
    ) {
        self.authRepository = authRepository
        self.getMyProfile = getMyProfile
        self.updateMyProfile = updateMyProfile
        self.authEnabledValue = authEnabled
        self.signInWithAppleEnabledValue = signInWithAppleEnabled
        self.googleSignInEnabledValue = googleSignInEnabled
        self.guestModeEnabledValue = guestModeEnabled
        self.adminMenuEnabledValue = adminMenuEnabled
        self.safeModeEnabledValue = safeModeEnabled
        self.termsOfServiceURLValue = termsOfServiceURL
        self.privacyPolicyURLValue = privacyPolicyURL
        self.loadPersistedAuthError = loadPersistedAuthError

        if !authEnabled {
            let fallbackSession = makeLocalPreviewSession()
            authState = .signedIn(fallbackSession)
            currentFeatureAccess = FeatureAccessResolver.resolve(
                session: fallbackSession,
                creatorPassEntitled: false
            )
        }
    }

    var currentSession: AuthSession? {
        authState.session
    }

    var termsOfServiceURL: URL? {
        termsOfServiceURLValue
    }

    var privacyPolicyURL: URL? {
        privacyPolicyURLValue
    }

    var isSignedInOrGuest: Bool {
        switch authState {
        case .signedIn, .guest:
            return true
        case .loading, .signedOut, .needsProfileSetup, .failed:
            return false
        }
    }

    var isAuthEnabled: Bool {
        authEnabledValue
    }

    var shouldBypassLaunchGate: Bool {
        !authEnabledValue
    }

    var canUseAppleSignIn: Bool {
        authEnabledValue
            && signInWithAppleEnabledValue
            && authRepository.supportedProviders.contains(.signInWithApple)
    }

    var isGuest: Bool {
        currentSession?.isGuest == true
    }

    var isAdmin: Bool {
        adminMenuEnabledValue && currentSession?.isAdmin == true
    }

    var canUseGoogleSignIn: Bool {
        authEnabledValue
            && googleSignInEnabledValue
            && authRepository.supportedProviders.contains(.google)
    }

    var signInWithAppleEnabledForDiagnostics: Bool {
        signInWithAppleEnabledValue
    }

    var googleSignInEnabledForDiagnostics: Bool {
        googleSignInEnabledValue
    }

    var guestModeEnabledForDiagnostics: Bool {
        guestModeEnabledValue
    }

    var adminMenuEnabledForDiagnostics: Bool {
        adminMenuEnabledValue
    }

    var canUseGuestMode: Bool {
        guestModeEnabledValue && authRepository.supportedProviders.contains(.guest)
    }

    var supportsInteractiveAuth: Bool {
        authEnabledValue
    }

    var currentAuthStateText: String {
        switch authState {
        case .loading:
            return "loading"
        case .signedOut:
            return "signedOut"
        case .signedIn:
            return "signedIn"
        case .guest:
            return "guest"
        case .needsProfileSetup:
            return "needsProfileSetup"
        case .failed:
            return "failed"
        }
    }

    var diagnosticsSnapshot: AuthDiagnosticsSnapshot {
        AuthDiagnosticsSnapshot(
            authEnabled: authEnabledValue,
            signInWithAppleEnabled: signInWithAppleEnabledValue,
            googleSignInEnabled: googleSignInEnabledValue,
            guestModeEnabled: guestModeEnabledValue,
            adminMenuEnabled: adminMenuEnabledValue,
            safeModeEnabled: safeModeEnabledValue,
            authState: currentAuthStateText,
            provider: currentSession?.user.provider.rawValue ?? "none",
            userID: currentSession?.user.id,
            providerUserID: currentSession?.user.providerUserID,
            displayName: currentSession?.user.displayName,
            email: currentSession?.user.email,
            roles: currentSession?.roles.map(\.rawValue) ?? [],
            isAdmin: isAdmin,
            adminCapabilities: currentSession?.adminCapabilities.map(\.rawValue) ?? [],
            lastAuthError: lastAuthErrorDescription
        )
    }

    var diagnosticsReportText: String {
        diagnosticsSnapshot.reportText
    }

    var accountStatusText: String {
        if !authEnabledValue {
            return "ログインなしで利用中"
        }
        guard let currentSession else {
            return "未ログイン"
        }
        if currentSession.isGuest {
            return "この端末でお試し中"
        }
        return "\(currentSession.user.provider.displayName)でログイン中"
    }

    var accountDetailText: String {
        if !authEnabledValue {
            return "認証は現在無効です。起動安定化のため、既存のローカル体験でそのまま利用できます。"
        }
        guard let currentSession else {
            return "日記の回答は自動で公開されず、共有は自分で選んだときだけ行われます。"
        }

        if currentSession.isGuest {
            return "ゲストでは記録と見た目はこの端末で試せます。DMと管理者機能は使えません。"
        }

        if currentFeatureAccess.isAdminBypassingCreatorFeatures {
            return "管理者権限で Creator 機能と QA 機能が有効です。StoreKit の加入状態は変更されません。"
        }

        if creatorPassEntitled {
            return "Creator Pass が有効です。コミュニティ作成とお題カスタマイズを使えます。"
        }

        return "日記の回答は自動で公開されません。コミュニティ参加は無料で、共有は自分で選んだときだけ行われます。"
    }

    func load() async {
        isBusy = true
        defer { isBusy = false }
        guard authEnabledValue else {
            lastAuthErrorDescription = nil
            applySession(makeLocalPreviewSession())
            return
        }
        lastAuthErrorDescription = loadPersistedAuthError()
        applySession(authRepository.refreshSession())
    }

    func showWelcome() {
        entryScreen = .welcome
        clearInlineMessage()
    }

    func showLogin() {
        entryScreen = .login
        clearInlineMessage()
    }

    func showRegister() {
        entryScreen = .register
        clearInlineMessage()
    }

    func signInWithApple(
        userID: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) {
        guard canUseAppleSignIn else {
            let error = AuthError.providerUnavailable(.signInWithApple)
            authState = .failed(error)
            inlineMessage = error.localizedDescription
            lastAuthErrorDescription = error.localizedDescription
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let session = try authRepository.signInWithApple(
                userID: userID,
                email: email,
                givenName: givenName,
                familyName: familyName
            )
            applySession(session)
            lastAuthErrorDescription = nil
            inlineMessage = session.requiresProfileSetup
                ? "表示名を整えると、プロフィールや共有カードが分かりやすくなります。"
                : "Appleでログインしました"
        } catch let error as AuthError {
            authState = .failed(error)
            inlineMessage = error.localizedDescription
            lastAuthErrorDescription = error.localizedDescription
            entryScreen = .login
        } catch {
            authState = .failed(.unknown(error.localizedDescription))
            inlineMessage = error.localizedDescription
            lastAuthErrorDescription = error.localizedDescription
            entryScreen = .login
        }
    }

    func signInWithGoogle() {
        if !canUseGoogleSignIn {
            let error = AuthError.providerNotConfigured(.google)
            authState = .failed(error)
            inlineMessage = error.localizedDescription
            lastAuthErrorDescription = error.localizedDescription
            return
        }

        inlineMessage = "Googleログインは OAuth 設定の最終確認後に有効になります。Appleログインを優先して利用できます。"
    }

    func continueAsGuest() {
        guard canUseGuestMode else {
            inlineMessage = "ゲスト利用は現在無効です"
            return
        }
        isBusy = true
        defer { isBusy = false }

        let profile = getMyProfile()
        let defaultName = profile.displayName == "Me" ? "ゲスト" : profile.displayName
        let session = authRepository.signInAsGuest(displayName: defaultName)
        applySession(session)
        lastAuthErrorDescription = nil
        inlineMessage = "ゲストとして開始しました。あとから Apple でログインできます。"
    }

    func completeAccountSetup() {
        let normalized = pendingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            inlineMessage = "表示名を入力してください"
            return
        }

        updateMyProfile(displayName: normalized)
        let refreshed = authRepository.refreshSession()
        applySession(refreshed)
        inlineMessage = "表示名を保存しました"
    }

    func signOut() {
        guard authEnabledValue else {
            inlineMessage = "認証は現在無効です"
            return
        }
        authRepository.signOut()
        creatorPassEntitled = false
        currentFeatureAccess = .signedOutDefault
        authState = .signedOut
        pendingDisplayName = ""
        entryScreen = .welcome
        lastAuthErrorDescription = nil
        inlineMessage = "ログアウトしました"
    }

    func requestAccountDeletionSupport() {
        do {
            try authRepository.requestAccountDeletion()
        } catch let error as AuthError {
            inlineMessage = error.localizedDescription
        } catch {
            inlineMessage = error.localizedDescription
        }
    }

    func updateCreatorPassEntitlement(_ isEntitled: Bool) {
        creatorPassEntitled = isEntitled
        currentFeatureAccess = FeatureAccessResolver.resolve(
            session: authState.session,
            creatorPassEntitled: creatorPassEntitled
        )
    }

    func clearInlineMessage() {
        inlineMessage = nil
    }

    private func applySession(_ session: AuthSession?) {
        currentFeatureAccess = FeatureAccessResolver.resolve(
            session: session,
            creatorPassEntitled: creatorPassEntitled
        )

        guard let session else {
            authState = .signedOut
            pendingDisplayName = ""
            if entryScreen == .setup {
                entryScreen = .welcome
            }
            return
        }

        pendingDisplayName = session.user.displayName == "Me" ? "" : session.user.displayName

        if session.isGuest {
            authState = .guest(session)
            entryScreen = .welcome
            return
        }

        if session.requiresProfileSetup {
            authState = .needsProfileSetup(session)
            entryScreen = .setup
            return
        }

        authState = .signedIn(session)
        entryScreen = .welcome
    }

    private func makeLocalPreviewSession() -> AuthSession {
        let profile = getMyProfile()
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "ローカルユーザー"
            : profile.displayName
        return AuthSession(
            user: AuthUser(
                id: profile.userId,
                providerUserID: nil,
                displayName: displayName,
                email: nil,
                provider: .localDeveloperPreview
            ),
            roles: [.user],
            adminCapabilities: [],
            requiresProfileSetup: false
        )
    }
}
