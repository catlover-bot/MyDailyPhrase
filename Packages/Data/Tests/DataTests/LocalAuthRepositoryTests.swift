import Foundation
import Testing
import Domain
@testable import Data

@Suite("Local auth repository")
struct LocalAuthRepositoryTests {
    @Test("normal user is not admin")
    func normalUserIsNotAdmin() throws {
        let repo = makeRepository(
            configuration: .init(
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminAppleUserIDs: ["admin-user"],
                adminEmails: []
            )
        )

        let session = try repo.signInWithApple(
            userID: "regular-user",
            email: "user@example.com",
            givenName: "Taro",
            familyName: "Yamada"
        )

        #expect(repo.isAdmin(session: session) == false)
        #expect(repo.adminCapabilities(session: session).isEmpty)
        #expect(session.roles.contains(.admin) == false)
    }

    @Test("empty admin allowlist does not crash")
    func emptyAdminAllowlistIsSafe() throws {
        let repo = makeRepository(
            configuration: .init(
                signInWithAppleEnabled: true,
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminMenuEnabled: true,
                adminAppleUserIDs: [],
                adminEmails: []
            )
        )

        let session = try repo.signInWithApple(
            userID: "plain-user",
            email: "plain@example.com",
            givenName: "Hanako",
            familyName: nil
        )

        #expect(repo.isAdmin(session: session) == false)
        #expect(repo.adminCapabilities(session: session).isEmpty)
    }

    @Test("allowlisted admin is admin")
    func allowlistedAdminIsAdmin() throws {
        let repo = makeRepository(
            configuration: .init(
                signInWithAppleEnabled: true,
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminMenuEnabled: true,
                adminAppleUserIDs: ["apple-admin-1"],
                adminEmails: []
            )
        )

        let session = try repo.signInWithApple(
            userID: "apple-admin-1",
            email: nil,
            givenName: "Owner",
            familyName: nil
        )

        #expect(repo.isAdmin(session: session))
        #expect(repo.adminCapabilities(session: session).contains(.bypassCreatorPassForAdmin))
        #expect(session.roles.contains(.admin))
    }

    @Test("owner email allowlist accepts dimension0122 Gmail address")
    func ownerEmailAllowlistAcceptsGmailAddress() throws {
        let repo = makeRepository(
            configuration: .init(
                signInWithAppleEnabled: true,
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminMenuEnabled: true,
                adminAppleUserIDs: [],
                adminEmails: ["dimension0122@gmail.com"]
            )
        )

        let session = try repo.signInWithApple(
            userID: "apple-owner-id",
            email: "Dimension0122@Gmail.com",
            givenName: "Owner",
            familyName: nil
        )

        #expect(repo.isAdmin(session: session))
        #expect(session.roles.contains(.admin))
        #expect(session.adminCapabilities.contains(.viewDiagnostics))
    }

    @Test("admin allowlist does not grant admin when admin menu is disabled")
    func adminAllowlistRequiresAdminMenuFlag() throws {
        let repo = makeRepository(
            configuration: .init(
                signInWithAppleEnabled: true,
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminMenuEnabled: false,
                adminAppleUserIDs: ["apple-owner-id"],
                adminEmails: ["dimension0122@gmail.com"]
            )
        )

        let session = try repo.signInWithApple(
            userID: "apple-owner-id",
            email: "dimension0122@gmail.com",
            givenName: "Owner",
            familyName: nil
        )

        #expect(repo.isAdmin(session: session) == false)
        #expect(session.roles.contains(.admin) == false)
        #expect(session.adminCapabilities.isEmpty)
    }

    @Test("google sign in requires safe configuration")
    func googleSignInRequiresConfiguration() {
        let repo = makeRepository(configuration: .init(googleOAuthEnabled: false))

        #expect(throws: AuthError.providerNotConfigured(.google)) {
            _ = try repo.signInWithGoogle(
                subject: "google-user",
                email: "user@example.com",
                displayName: "User"
            )
        }
    }

    @Test("sign in with Apple unavailable state is safe")
    func signInWithAppleUnavailableStateIsSafe() {
        let repo = makeRepository(
            configuration: .init(
                signInWithAppleEnabled: false,
                googleOAuthEnabled: false,
                guestModeEnabled: true,
                adminMenuEnabled: false
            )
        )

        #expect(repo.supportedProviders.contains(.signInWithApple) == false)
        #expect(throws: AuthError.providerUnavailable(.signInWithApple)) {
            _ = try repo.signInWithApple(
                userID: "apple-user",
                email: nil,
                givenName: nil,
                familyName: nil
            )
        }
    }

    @Test("legacy linked auth can restore local session")
    func legacyLinkedAuthRestoresSession() {
        let profileRepo = InMemoryUserProfileRepository()
        profileRepo.saveMyProfile(
            UserProfile(
                userId: "profile-1",
                displayName: "Linked User",
                linkedAuthProvider: "apple",
                linkedAuthUserId: "apple-linked-1",
                linkedAuthAt: Date(timeIntervalSince1970: 100)
            )
        )
        let defaults = UserDefaults(suiteName: "LocalAuthRepositoryTests.restore.\(UUID().uuidString)")!
        let repo = LocalAuthRepository(
            defaults: defaults,
            profileRepository: profileRepo,
            configuration: .init()
        )

        let session = repo.refreshSession()

        #expect(session?.user.provider == .signInWithApple)
        #expect(session?.user.providerUserID == "apple-linked-1")
        #expect(session?.user.displayName == "Linked User")
    }

    @Test("corrupt saved auth session falls back safely")
    func corruptSavedSessionFallsBackSafely() {
        let suiteName = "LocalAuthRepositoryTests.corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: "MyDailyPhrase.auth.session.v1")

        let repo = LocalAuthRepository(
            defaults: defaults,
            profileRepository: InMemoryUserProfileRepository(),
            configuration: .init()
        )

        let session = repo.refreshSession()

        #expect(session == nil)
        #expect(defaults.string(forKey: LocalAuthRepository.lastDiagnosticsErrorKey) != nil)
        #expect(defaults.data(forKey: "MyDailyPhrase.auth.session.v1") == nil)
    }

    private func makeRepository(configuration: LocalAuthRepository.Configuration) -> LocalAuthRepository {
        let defaults = UserDefaults(suiteName: "LocalAuthRepositoryTests.\(UUID().uuidString)")!
        return LocalAuthRepository(
            defaults: defaults,
            profileRepository: InMemoryUserProfileRepository(),
            configuration: configuration,
            makeUserID: { "profile-user-1" }
        )
    }
}

private final class InMemoryUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private var profile: UserProfile?

    func getMyProfile() -> UserProfile? {
        profile
    }

    func saveMyProfile(_ profile: UserProfile) {
        self.profile = profile
    }

    func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        var copy = profile ?? makeIfMissing()
        mutate(&copy)
        copy.normalize()
        profile = copy
        return copy
    }
}
