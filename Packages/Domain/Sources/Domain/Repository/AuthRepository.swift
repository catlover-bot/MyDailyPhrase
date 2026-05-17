import Foundation

public protocol AuthRepository: Sendable {
    var currentSession: AuthSession? { get }
    var supportedProviders: Set<AuthProvider> { get }

    func signInWithApple(
        userID: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) throws -> AuthSession

    func signInWithGoogle(
        subject: String,
        email: String?,
        displayName: String?
    ) throws -> AuthSession

    func signInAsGuest(displayName: String?) -> AuthSession
    func signOut()
    func refreshSession() -> AuthSession?
    func requestAccountDeletion() throws
    func isAdmin(session: AuthSession?) -> Bool
    func adminCapabilities(session: AuthSession?) -> Set<AdminCapability>
}
