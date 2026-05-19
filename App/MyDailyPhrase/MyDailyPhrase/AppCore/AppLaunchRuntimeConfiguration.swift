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

    var policy: LaunchSafetyPolicy {
        LaunchSafetyPolicy(
            authEnabledConfigured: authEnabledConfigured,
            guestModeEnabled: guestModeEnabled,
            adminMenuEnabledConfigured: adminMenuEnabledConfigured,
            safeModeEnabled: safeModeEnabled
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

    static func load(from bundle: Bundle = .main) -> AppLaunchRuntimeConfiguration {
        AppLaunchRuntimeConfiguration(
            authEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_ENABLED") ?? false,
            signInWithAppleEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_SIGN_IN_WITH_APPLE_ENABLED") ?? false,
            googleSignInEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_GOOGLE_SIGN_IN_ENABLED") ?? false,
            guestModeEnabled: bundle.boolValue(forInfoDictionaryKey: "AUTH_GUEST_MODE_ENABLED") ?? true,
            adminMenuEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "AUTH_ADMIN_MENU_ENABLED") ?? false,
            safeModeEnabled: bundle.boolValue(forInfoDictionaryKey: "APP_SAFE_MODE") ?? false
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
    let currentAuthStateText: String
    let userID: String?
    let email: String?
    let roleLabels: [String]
    let isAdmin: Bool
    let capabilityLabels: [String]
    let lastAuthErrorDescription: String?
    let diagnosticsReportText: String
    let canAccessAdminMenu: Bool
    let adminCapabilities: Set<AdminCapability>

    init(authViewModel: AppAuthViewModel, safeModeEnabled: Bool) {
        self.accountStatusText = authViewModel.accountStatusText
        self.accountDetailText = authViewModel.accountDetailText
        self.providerDisplayName = authViewModel.currentSession?.user.provider.displayName ?? "未ログイン"
        self.isGuest = authViewModel.isGuest
        self.adminStatusLabel = authViewModel.currentFeatureAccess.adminStatusLabel
        self.supportsInteractiveAuth = authViewModel.supportsInteractiveAuth
        self.isAuthEnabled = authViewModel.isAuthEnabled
        self.isSafeModeEnabled = safeModeEnabled
        self.currentAuthStateText = authViewModel.currentAuthStateText
        self.userID = authViewModel.currentSession?.user.id
        self.email = authViewModel.currentSession?.user.email
        self.roleLabels = authViewModel.currentSession?.roles.map(\.label) ?? []
        self.isAdmin = authViewModel.isAdmin
        self.capabilityLabels = authViewModel.currentSession?.adminCapabilities.map(\.label) ?? []
        self.lastAuthErrorDescription = authViewModel.lastAuthErrorDescription
        self.diagnosticsReportText = authViewModel.diagnosticsReportText
        self.canAccessAdminMenu = authViewModel.currentFeatureAccess.canAccessAdminMenu
        self.adminCapabilities = Set(authViewModel.currentFeatureAccess.adminCapabilities)
    }

    static func localSafeMode() -> SettingsAuthContext {
        SettingsAuthContext(
            accountStatusText: "ログインなしで利用中",
            accountDetailText: "認証と管理者メニューは安全確認が終わるまで無効です。日記、ガチャ、見た目の変更はこれまで通りこの端末で利用できます。",
            providerDisplayName: "ローカル体験",
            isGuest: false,
            adminStatusLabel: nil,
            supportsInteractiveAuth: false,
            isAuthEnabled: false,
            isSafeModeEnabled: true,
            currentAuthStateText: "safeMode",
            userID: nil,
            email: nil,
            roleLabels: [],
            isAdmin: false,
            capabilityLabels: [],
            lastAuthErrorDescription: nil,
            diagnosticsReportText: [
                "authEnabled: false",
                "safeModeEnabled: true",
                "authState: safeMode",
                "provider: none",
                "userId: none",
                "email: none",
                "roles: none",
                "isAdmin: false",
                "adminCapabilities: none",
                "lastAuthError: none"
            ].joined(separator: "\n"),
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
        currentAuthStateText: String,
        userID: String?,
        email: String?,
        roleLabels: [String],
        isAdmin: Bool,
        capabilityLabels: [String],
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
        self.currentAuthStateText = currentAuthStateText
        self.userID = userID
        self.email = email
        self.roleLabels = roleLabels
        self.isAdmin = isAdmin
        self.capabilityLabels = capabilityLabels
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
