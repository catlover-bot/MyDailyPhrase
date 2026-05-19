import Foundation

public struct LaunchSafetyPolicy: Equatable, Sendable {
    public let authEnabledConfigured: Bool
    public let guestModeEnabled: Bool
    public let adminMenuEnabledConfigured: Bool
    public let safeModeEnabled: Bool
    public let authTestEntryEnabledConfigured: Bool
    public let manualAppleSignInEnabledConfigured: Bool

    public init(
        authEnabledConfigured: Bool,
        guestModeEnabled: Bool,
        adminMenuEnabledConfigured: Bool,
        safeModeEnabled: Bool,
        authTestEntryEnabledConfigured: Bool = false,
        manualAppleSignInEnabledConfigured: Bool = false
    ) {
        self.authEnabledConfigured = authEnabledConfigured
        self.guestModeEnabled = guestModeEnabled
        self.adminMenuEnabledConfigured = adminMenuEnabledConfigured
        self.safeModeEnabled = safeModeEnabled
        self.authTestEntryEnabledConfigured = authTestEntryEnabledConfigured
        self.manualAppleSignInEnabledConfigured = manualAppleSignInEnabledConfigured
    }

    public var effectiveAuthEnabled: Bool {
        authEnabledConfigured && !safeModeEnabled
    }

    public var shouldConstructAuthFlow: Bool {
        effectiveAuthEnabled
    }

    public var shouldShowMainShellImmediately: Bool {
        safeModeEnabled || !authEnabledConfigured
    }

    public var effectiveAdminMenuEnabled: Bool {
        effectiveAuthEnabled && adminMenuEnabledConfigured
    }

    public var socialPrototypesEnabled: Bool {
        !safeModeEnabled
    }

    public func shouldShowAuthTestEntry(isDebugBuild: Bool) -> Bool {
        isDebugBuild || authTestEntryEnabledConfigured
    }

    public var manualAppleSignInTestEnabled: Bool {
        authTestEntryEnabledConfigured && manualAppleSignInEnabledConfigured
    }
}
