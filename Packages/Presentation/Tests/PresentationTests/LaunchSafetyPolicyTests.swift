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
            authTestEntryEnabledConfigured: true,
            manualAppleSignInEnabledConfigured: true
        )

        #expect(policy.effectiveAuthEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
        #expect(policy.effectiveAdminMenuEnabled == false)
        #expect(policy.socialPrototypesEnabled == false)
        #expect(policy.shouldShowAuthTestEntry(isDebugBuild: false) == true)
        #expect(policy.manualAppleSignInTestEnabled)
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
            authTestEntryEnabledConfigured: true,
            manualAppleSignInEnabledConfigured: true
        )

        #expect(policy.shouldShowAuthTestEntry(isDebugBuild: false))
        #expect(policy.manualAppleSignInTestEnabled)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.shouldShowMainShellImmediately == true)
    }

    @Test("manual Apple sign in flag is independent from root auth gate")
    func manualAppleSignInDoesNotEnableRootAuthGate() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: false,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: false,
            safeModeEnabled: true,
            authTestEntryEnabledConfigured: true,
            manualAppleSignInEnabledConfigured: true
        )

        #expect(policy.manualAppleSignInTestEnabled)
        #expect(policy.effectiveAuthEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
        #expect(policy.effectiveAdminMenuEnabled == false)
    }

    @Test("manual Apple sign in stays disabled without test entry")
    func manualAppleSignInRequiresTestEntry() {
        let policy = LaunchSafetyPolicy(
            authEnabledConfigured: false,
            guestModeEnabled: true,
            adminMenuEnabledConfigured: false,
            safeModeEnabled: true,
            authTestEntryEnabledConfigured: false,
            manualAppleSignInEnabledConfigured: true
        )

        #expect(policy.manualAppleSignInTestEnabled == false)
        #expect(policy.shouldConstructAuthFlow == false)
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
