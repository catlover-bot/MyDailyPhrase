import Testing
@testable import Presentation

struct LaunchSafetyPolicyTests {
    @Test("safe mode disables auth, admin, and social launch paths")
    func safeModeDisablesRiskyStartupPaths() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: true,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: true,
            safeModeEnabled: true,
            authTestEntryEnabledConfigured: true
        )

        #expect(policy.effectiveAuthEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
        #expect(policy.effectiveAdminMenuEnabled == false)
        #expect(policy.socialPrototypesEnabled == false)
        #expect(policy.shouldShowAuthTestEntry(isDebugBuild: false) == true)
    }

    @Test("auth disabled config still launches main shell safely")
    func authDisabledConfigLaunchesSafely() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: false,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: false,
            safeModeEnabled: false
        )

        #expect(policy.effectiveAuthEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
        #expect(policy.effectiveAdminMenuEnabled == false)
        #expect(policy.socialPrototypesEnabled == true)
    }

    @Test("optional auth test entry does not affect launch path")
    func authTestEntryDoesNotAffectLaunchPath() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: false,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: false,
            safeModeEnabled: true,
            authTestEntryEnabledConfigured: true
        )

        #expect(policy.shouldShowAuthTestEntry(isDebugBuild: false))
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
    }

    @Test("debug build can show auth test entry without runtime flag")
    func debugBuildCanShowAuthTestEntry() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: false,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: false,
            safeModeEnabled: true,
            authTestEntryEnabledConfigured: false
        )

        #expect(policy.shouldShowAuthTestEntry(isDebugBuild: true))
        #expect(policy.shouldConstructAuthFlow == false)
    }
}
