import Foundation
import Presentation
import Domain

struct AppLaunchRuntimeConfiguration: Sendable {
    let authEnabledConfigured: Bool
    let signInWithAppleEnabledConfigured: Bool
    let googleSignInEnabledConfigured: Bool
    let guestModeEnabled: Bool
    let adminMenuEnabledConfigured: Bool
    let safeModeEnabled: Bool
    let authTestEntryEnabledConfigured: Bool
    let manualAppleSignInEnabledConfigured: Bool

    var policy: LaunchSafetyPolicy {
        LaunchSafetyPolicy(
            authEnabledConfigured: authEnabledConfigured,
            guestModeEnabled: guestModeEnabled,
            adminMenuEnabledConfigured: adminMenuEnabledConfigured,
            safeModeEnabled: safeModeEnabled,
            authTestEntryEnabledConfigured: authTestEntryEnabledConfigured,
            manualAppleSignInEnabledConfigured: manualAppleSignInEnabledConfigured
        )
    }

    var effectiveAuthEnabled: Bool {
        policy.effectiveAuthEnabled
    }

    var signInWithAppleEnabled: Bool {
        effectiveAuthEnabled && signInWithAppleEnabledConfigured
    }

    var googleSignInEnabled: Bool {
        effectiveAuthEnabled && googleSignInEnabledConfigured
    }

    var adminMenuEnabled: Bool {
        policy.effectiveAdminMenuEnabled
    }

    var authTestEntryEnabled: Bool {
#if DEBUG
        return true
#else
        return policy.shouldShowAuthTestEntry(isDebugBuild: false)
#endif
    }

    var rootAuthGateEnabled: Bool {
        policy.shouldConstructAuthFlow
    }

    var manualAppleSignInEnabled: Bool {
        authTestEntryEnabled && manualAppleSignInEnabledConfigured
    }

    static func load(from bundle: Bundle = .main) -> AppLaunchRuntimeConfiguration {
        AppLaunchRuntimeConfiguration(
            authEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_ENABLED") ?? false,
            signInWithAppleEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_SIGN_IN_WITH_APPLE_ENABLED") ?? false,
            googleSignInEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_GOOGLE_SIGN_IN_ENABLED") ?? false,
            guestModeEnabled: bundle.boolValue(forInfoDictionaryKey: "AUTH_GUEST_MODE_ENABLED") ?? true,
            adminMenuEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_ADMIN_MENU_ENABLED") ?? false,
            safeModeEnabled: bundle.boolValue(forInfoDictionaryKey: "APP_SAFE_MODE") ?? false,
            authTestEntryEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_TEST_ENTRY_ENABLED") ?? false,
            manualAppleSignInEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_MANUAL_APPLE_SIGN_IN_ENABLED") ?? false
        )
    }
}

struct SettingsAuthContext {
    let accountStatusText: String
    let accountDetailText: String
    let providerDisplayName: String
    let isGuest: Bool
    let adminStatusLabel: String?
    let supportsInteractiveAuth: Bool
    let isAuthEnabled: Bool
    let isSafeModeEnabled: Bool
    let rootAuthGateEnabled: Bool
    let manualAuthTestEntryEnabled: Bool
    let manualAppleSignInEnabled: Bool
    let currentAuthStateText: String
    let userID: String?
    let providerUserID: String?
    let displayName: String?
    let email: String?
    let roleLabels: [String]
    let isAdmin: Bool
    let capabilityLabels: [String]
    let signInWithAppleEnabled: Bool
    let googleSignInEnabled: Bool
    let guestModeEnabled: Bool
    let adminMenuEnabled: Bool
    let lastAuthErrorDescription: String?
    let diagnosticsReportText: String
    let canAccessAdminMenu: Bool
    let adminCapabilities: Set<AdminCapability>

    init(authViewModel: AppAuthViewModel, launchConfiguration: AppLaunchRuntimeConfiguration) {
        self.accountStatusText = authViewModel.accountStatusText
        self.accountDetailText = authViewModel.accountDetailText
        self.providerDisplayName = authViewModel.currentSession?.user.provider.displayName ?? "未ログイン"
        self.isGuest = authViewModel.isGuest
        self.adminStatusLabel = authViewModel.currentFeatureAccess.adminStatusLabel
        self.supportsInteractiveAuth = authViewModel.supportsInteractiveAuth
        self.isAuthEnabled = authViewModel.isAuthEnabled
        self.isSafeModeEnabled = launchConfiguration.safeModeEnabled
        self.rootAuthGateEnabled = launchConfiguration.rootAuthGateEnabled
        self.manualAuthTestEntryEnabled = launchConfiguration.authTestEntryEnabled
        self.manualAppleSignInEnabled = launchConfiguration.manualAppleSignInEnabled
        self.currentAuthStateText = authViewModel.currentAuthStateText
        self.userID = authViewModel.currentSession?.user.id
        self.providerUserID = authViewModel.currentSession?.user.providerUserID
        self.displayName = authViewModel.currentSession?.user.displayName
        self.email = authViewModel.currentSession?.user.email
        self.roleLabels = authViewModel.currentSession?.roles.map(\.label) ?? []
        self.isAdmin = authViewModel.isAdmin
        self.capabilityLabels = authViewModel.currentSession?.adminCapabilities.map(\.label) ?? []
        self.signInWithAppleEnabled = authViewModel.signInWithAppleEnabledForDiagnostics
        self.googleSignInEnabled = authViewModel.googleSignInEnabledForDiagnostics
        self.guestModeEnabled = authViewModel.guestModeEnabledForDiagnostics
        self.adminMenuEnabled = authViewModel.adminMenuEnabledForDiagnostics
        self.lastAuthErrorDescription = authViewModel.lastAuthErrorDescription
        self.diagnosticsReportText = authViewModel.diagnosticsReportText
        self.canAccessAdminMenu = authViewModel.currentFeatureAccess.canAccessAdminMenu
        self.adminCapabilities = Set(authViewModel.currentFeatureAccess.adminCapabilities)
    }

    static func localSafeMode(launchConfiguration: AppLaunchRuntimeConfiguration? = nil) -> SettingsAuthContext {
        let signInWithAppleEnabled = launchConfiguration?.signInWithAppleEnabled ?? false
        let googleSignInEnabled = launchConfiguration?.googleSignInEnabled ?? false
        let guestModeEnabled = launchConfiguration?.guestModeEnabled ?? true
        let adminMenuEnabled = launchConfiguration?.adminMenuEnabled ?? false
        let safeModeEnabled = launchConfiguration?.safeModeEnabled ?? true
        let rootAuthGateEnabled = launchConfiguration?.rootAuthGateEnabled ?? false
        let manualAuthTestEntryEnabled = launchConfiguration?.authTestEntryEnabled ?? false
        let manualAppleSignInEnabled = launchConfiguration?.manualAppleSignInEnabled ?? false
        let snapshot = AuthDiagnosticsSnapshot(
            authEnabled: false,
            signInWithAppleEnabled: signInWithAppleEnabled,
            googleSignInEnabled: googleSignInEnabled,
            guestModeEnabled: guestModeEnabled,
            adminMenuEnabled: adminMenuEnabled,
            safeModeEnabled: safeModeEnabled,
            rootAuthGateEnabled: rootAuthGateEnabled,
            manualAuthTestEntryEnabled: manualAuthTestEntryEnabled,
            manualAppleSignInEnabled: manualAppleSignInEnabled,
            authState: "safeMode",
            provider: "none",
            userID: nil,
            providerUserID: nil,
            displayName: nil,
            email: nil,
            roles: [],
            isAdmin: false,
            adminCapabilities: [],
            lastAuthError: nil
        )
        return SettingsAuthContext(
            accountStatusText: "ログインなしで利用中",
            accountDetailText: "認証と管理者メニューは安全確認が終わるまで無効です。日記、ガチャ、見た目の変更はこれまで通りこの端末で利用できます。",
            providerDisplayName: "ローカル体験",
            isGuest: false,
            adminStatusLabel: nil,
            supportsInteractiveAuth: false,
            isAuthEnabled: false,
            isSafeModeEnabled: safeModeEnabled,
            rootAuthGateEnabled: rootAuthGateEnabled,
            manualAuthTestEntryEnabled: manualAuthTestEntryEnabled,
            manualAppleSignInEnabled: manualAppleSignInEnabled,
            currentAuthStateText: "safeMode",
            userID: nil,
            providerUserID: nil,
            displayName: nil,
            email: nil,
            roleLabels: [],
            isAdmin: false,
            capabilityLabels: [],
            signInWithAppleEnabled: signInWithAppleEnabled,
            googleSignInEnabled: googleSignInEnabled,
            guestModeEnabled: guestModeEnabled,
            adminMenuEnabled: adminMenuEnabled,
            lastAuthErrorDescription: nil,
            diagnosticsReportText: snapshot.reportText,
            canAccessAdminMenu: false,
            adminCapabilities: []
        )
    }

    private init(
        accountStatusText: String,
        accountDetailText: String,
        providerDisplayName: String,
        isGuest: Bool,
        adminStatusLabel: String?,
        supportsInteractiveAuth: Bool,
        isAuthEnabled: Bool,
        isSafeModeEnabled: Bool,
        rootAuthGateEnabled: Bool,
        manualAuthTestEntryEnabled: Bool,
        manualAppleSignInEnabled: Bool,
        currentAuthStateText: String,
        userID: String?,
        providerUserID: String?,
        displayName: String?,
        email: String?,
        roleLabels: [String],
        isAdmin: Bool,
        capabilityLabels: [String],
        signInWithAppleEnabled: Bool,
        googleSignInEnabled: Bool,
        guestModeEnabled: Bool,
        adminMenuEnabled: Bool,
        lastAuthErrorDescription: String?,
        diagnosticsReportText: String,
        canAccessAdminMenu: Bool,
        adminCapabilities: Set<AdminCapability>
    ) {
        self.accountStatusText = accountStatusText
        self.accountDetailText = accountDetailText
        self.providerDisplayName = providerDisplayName
        self.isGuest = isGuest
        self.adminStatusLabel = adminStatusLabel
        self.supportsInteractiveAuth = supportsInteractiveAuth
        self.isAuthEnabled = isAuthEnabled
        self.isSafeModeEnabled = isSafeModeEnabled
        self.rootAuthGateEnabled = rootAuthGateEnabled
        self.manualAuthTestEntryEnabled = manualAuthTestEntryEnabled
        self.manualAppleSignInEnabled = manualAppleSignInEnabled
        self.currentAuthStateText = currentAuthStateText
        self.userID = userID
        self.providerUserID = providerUserID
        self.displayName = displayName
        self.email = email
        self.roleLabels = roleLabels
        self.isAdmin = isAdmin
        self.capabilityLabels = capabilityLabels
        self.signInWithAppleEnabled = signInWithAppleEnabled
        self.googleSignInEnabled = googleSignInEnabled
        self.guestModeEnabled = guestModeEnabled
        self.adminMenuEnabled = adminMenuEnabled
        self.lastAuthErrorDescription = lastAuthErrorDescription
        self.diagnosticsReportText = diagnosticsReportText
        self.canAccessAdminMenu = canAccessAdminMenu
        self.adminCapabilities = adminCapabilities
    }
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        if let value = object(forInfoDictionaryKey: key) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func boolValue(forInfoDictionaryKey key: String) -> Bool? {
        if let number = object(forInfoDictionaryKey: key) as? NSNumber {
            return number.boolValue
        }
        guard let raw = stringValue(forInfoDictionaryKey: key)?.lowercased() else {
            return nil
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }
}
