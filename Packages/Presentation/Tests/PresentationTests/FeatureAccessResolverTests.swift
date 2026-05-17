import Testing
import Domain
@testable import Presentation

@Suite("Feature access resolver")
struct FeatureAccessResolverTests {
    @Test("normal unpaid user cannot create community")
    func normalUserCannotCreateCommunityWithoutPass() {
        let snapshot = FeatureAccessResolver.resolve(
            session: makeSession(provider: .signInWithApple, roles: [.user]),
            creatorPassEntitled: false
        )

        #expect(snapshot.canCreateCommunity == false)
        #expect(snapshot.canAccessAdminMenu == false)
        #expect(snapshot.creatorFeatureSource == .none)
    }

    @Test("Creator Pass user can create community")
    func creatorPassUserCanCreateCommunity() {
        let snapshot = FeatureAccessResolver.resolve(
            session: makeSession(provider: .signInWithApple, roles: [.user]),
            creatorPassEntitled: true
        )

        #expect(snapshot.canCreateCommunity)
        #expect(snapshot.canCustomizePrompts)
        #expect(snapshot.creatorFeatureSource == .storeKit)
    }

    @Test("admin can create community without Creator Pass")
    func adminBypassEnablesCreatorTools() {
        let snapshot = FeatureAccessResolver.resolve(
            session: makeSession(
                provider: .signInWithApple,
                roles: [.user, .admin],
                adminCapabilities: [.bypassCreatorPassForAdmin, .viewDiagnostics, .previewAllItems]
            ),
            creatorPassEntitled: false
        )

        #expect(snapshot.canCreateCommunity)
        #expect(snapshot.canPreviewAllItems)
        #expect(snapshot.canAccessAdminMenu)
        #expect(snapshot.storeKitCreatorPassActive == false)
        #expect(snapshot.creatorFeatureSource == .adminBypass)
    }

    @Test("guest cannot access admin")
    func guestCannotAccessAdmin() {
        let snapshot = FeatureAccessResolver.resolve(
            session: makeSession(provider: .guest, roles: [.user]),
            creatorPassEntitled: false
        )

        #expect(snapshot.isGuest)
        #expect(snapshot.canAccessAdminMenu == false)
        #expect(snapshot.canUseDMPrototype == false)
    }

    private func makeSession(
        provider: AuthProvider,
        roles: [UserRole],
        adminCapabilities: [AdminCapability] = []
    ) -> AuthSession {
        AuthSession(
            user: AuthUser(
                id: "user-1",
                providerUserID: provider == .guest ? nil : "provider-user-1",
                displayName: provider == .guest ? "ゲスト" : "User",
                email: provider == .guest ? nil : "user@example.com",
                provider: provider
            ),
            roles: roles,
            adminCapabilities: adminCapabilities,
            requiresProfileSetup: false
        )
    }
}
