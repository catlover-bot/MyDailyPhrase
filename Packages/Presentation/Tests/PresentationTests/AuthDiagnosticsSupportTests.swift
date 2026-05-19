import Testing
@testable import Presentation

struct AuthDiagnosticsSupportTests {
    @Test("copied auth diagnostics includes account identifiers")
    func reportTextIncludesAccountIdentifiers() {
        let snapshot = AuthDiagnosticsSnapshot(
            authEnabled: true,
            signInWithAppleEnabled: true,
            googleSignInEnabled: false,
            guestModeEnabled: true,
            adminMenuEnabled: true,
            safeModeEnabled: false,
            rootAuthGateEnabled: false,
            manualAuthTestEntryEnabled: true,
            manualAppleSignInEnabled: true,
            authState: "signedIn",
            provider: "signInWithApple",
            userID: "local-user-1",
            providerUserID: "apple-user-identifier",
            displayName: "Owner",
            email: "dimension0122@gmail.com",
            roles: ["user", "admin"],
            isAdmin: true,
            adminCapabilities: ["viewDiagnostics"],
            lastAuthError: nil
        )

        let report = snapshot.reportText

        #expect(report.contains("userId: local-user-1"))
        #expect(report.contains("providerUserId: apple-user-identifier"))
        #expect(report.contains("displayName: Owner"))
        #expect(report.contains("email: dimension0122@gmail.com"))
        #expect(report.contains("provider: signInWithApple"))
        #expect(report.contains("isAdmin: true"))
        #expect(report.contains("manualAppleSignInEnabled: true"))
    }

    @Test("empty diagnostics fields are copy-safe")
    func emptyDiagnosticsFieldsAreCopySafe() {
        let snapshot = AuthDiagnosticsSnapshot(
            authEnabled: false,
            signInWithAppleEnabled: false,
            googleSignInEnabled: false,
            guestModeEnabled: true,
            adminMenuEnabled: false,
            safeModeEnabled: true,
            rootAuthGateEnabled: false,
            manualAuthTestEntryEnabled: true,
            manualAppleSignInEnabled: false,
            authState: "safeMode",
            provider: "none",
            userID: nil,
            providerUserID: nil,
            email: nil,
            roles: [],
            isAdmin: false,
            adminCapabilities: [],
            lastAuthError: nil
        )

        let report = snapshot.reportText

        #expect(report.contains("userId: none"))
        #expect(report.contains("providerUserId: none"))
        #expect(report.contains("email: none"))
        #expect(report.contains("isAdmin: false"))
    }
}
