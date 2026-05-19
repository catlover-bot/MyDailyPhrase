import Testing
@testable import Presentation

struct LaunchSafetyPolicyTests {
    @Test("safe mode disables auth, admin, and social launch paths")
    func safeModeDisablesRiskyStartupPaths() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: true,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: true,
            safeModeEnabled: true
        )

        #expect(policy.effectiveAuthEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
        #expect(policy.effectiveAdminMenuEnabled == false)
        #expect(policy.socialPrototypesEnabled == false)
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
}
