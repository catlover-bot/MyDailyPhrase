import Foundation
import Domain

public struct AuthDiagnosticsSnapshot: Equatable, Sendable {
    public let authEnabled: Bool
    public let signInWithAppleEnabled: Bool
    public let googleSignInEnabled: Bool
    public let guestModeEnabled: Bool
    public let adminMenuEnabled: Bool
    public let safeModeEnabled: Bool
    public let rootAuthGateEnabled: Bool
    public let manualAuthTestEntryEnabled: Bool
    public let manualAppleSignInEnabled: Bool
    public let authState: String
    public let provider: String
    public let userID: String?
    public let providerUserID: String?
    public let displayName: String?
    public let email: String?
    public let roles: [String]
    public let isAdmin: Bool
    public let adminCapabilities: [String]
    public let lastAuthError: String?

    public init(
        authEnabled: Bool,
        signInWithAppleEnabled: Bool,
        googleSignInEnabled: Bool,
        guestModeEnabled: Bool,
        adminMenuEnabled: Bool,
        safeModeEnabled: Bool,
        rootAuthGateEnabled: Bool = false,
        manualAuthTestEntryEnabled: Bool = false,
        manualAppleSignInEnabled: Bool = false,
        authState: String,
        provider: String,
        userID: String?,
        providerUserID: String?,
        displayName: String? = nil,
        email: String?,
        roles: [String],
        isAdmin: Bool,
        adminCapabilities: [String],
        lastAuthError: String?
    ) {
        self.authEnabled = authEnabled
        self.signInWithAppleEnabled = signInWithAppleEnabled
        self.googleSignInEnabled = googleSignInEnabled
        self.guestModeEnabled = guestModeEnabled
        self.adminMenuEnabled = adminMenuEnabled
        self.safeModeEnabled = safeModeEnabled
        self.rootAuthGateEnabled = rootAuthGateEnabled
        self.manualAuthTestEntryEnabled = manualAuthTestEntryEnabled
        self.manualAppleSignInEnabled = manualAppleSignInEnabled
        self.authState = authState
        self.provider = provider
        self.userID = userID
        self.providerUserID = providerUserID
        self.displayName = displayName
        self.email = email
        self.roles = roles
        self.isAdmin = isAdmin
        self.adminCapabilities = adminCapabilities
        self.lastAuthError = lastAuthError
    }

    public var reportText: String {
        [
            "authEnabled: \(authEnabled)",
            "signInWithAppleEnabled: \(signInWithAppleEnabled)",
            "googleSignInEnabled: \(googleSignInEnabled)",
            "guestModeEnabled: \(guestModeEnabled)",
            "adminMenuEnabled: \(adminMenuEnabled)",
            "safeModeEnabled: \(safeModeEnabled)",
            "rootAuthGateEnabled: \(rootAuthGateEnabled)",
            "manualAuthTestEntryEnabled: \(manualAuthTestEntryEnabled)",
            "manualAppleSignInEnabled: \(manualAppleSignInEnabled)",
            "authState: \(authState)",
            "provider: \(provider)",
            "userId: \(userID ?? "none")",
            "providerUserId: \(providerUserID ?? "none")",
            "displayName: \(displayName ?? "none")",
            "email: \(email ?? "none")",
            "roles: \(roles.isEmpty ? "none" : roles.joined(separator: ", "))",
            "isAdmin: \(isAdmin)",
            "adminCapabilities: \(adminCapabilities.isEmpty ? "none" : adminCapabilities.joined(separator: ", "))",
            "lastAuthError: \(lastAuthError ?? "none")"
        ].joined(separator: "\n")
    }
}
