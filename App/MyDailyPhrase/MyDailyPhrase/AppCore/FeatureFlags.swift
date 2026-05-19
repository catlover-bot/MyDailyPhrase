import Foundation
import Presentation

enum FeatureFlags {
    private static let launchConfiguration = AppLaunchRuntimeConfiguration.load()

    static let paidGachaEnabled = ReleaseFeatureAvailability.paidGachaEnabled
    static let communityEnabled = false
    static let publicCommunityEnabled = ReleaseFeatureAvailability.publicCommunityEnabled
    static let communityLiteEnabled = ReleaseFeatureAvailability.communityLiteEnabled
    static let gameCommunityEnabled = ReleaseFeatureAvailability.gameCommunityEnabled
    static let socialGraphEnabled = launchConfiguration.policy.socialPrototypesEnabled
        && ReleaseFeatureAvailability.socialGraphEnabled
    static let publicUserDiscoveryEnabled = ReleaseFeatureAvailability.publicUserDiscoveryEnabled
    static let dmEnabled = launchConfiguration.policy.socialPrototypesEnabled
        && ReleaseFeatureAvailability.dmEnabled
    static let publicDMEnabled = ReleaseFeatureAvailability.publicDMEnabled
    static let creatorPassEnabled = ReleaseFeatureAvailability.creatorPassEnabled
    static let creatorCommunityCreationEnabled = ReleaseFeatureAvailability.creatorCommunityCreationEnabled
    static let creatorCommunityLocalDraftEnabled = ReleaseFeatureAvailability.creatorCommunityLocalDraftEnabled
    static let externalAccountLinkingEnabled = false
    static let advancedProfileToolsEnabled = false
    static let nativeSharingEnabled = ReleaseFeatureAvailability.nativeSharingEnabled
    static let themePreviewEnabled = ReleaseFeatureAvailability.themePreviewEnabled
    static let authEnabled = launchConfiguration.effectiveAuthEnabled
    static let signInWithAppleEnabled = launchConfiguration.signInWithAppleEnabled
    static let googleSignInEnabled = launchConfiguration.googleSignInEnabled
    static let guestModeEnabled = launchConfiguration.guestModeEnabled
    static let adminMenuEnabled = launchConfiguration.adminMenuEnabled
    static let safeModeEnabled = launchConfiguration.safeModeEnabled
    static let authTestEntryEnabled = launchConfiguration.authTestEntryEnabled
}

struct CreatorEntitlementService {
    static let debugOverrideKey = "MyDailyPhrase.creatorPass.debugOverride.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func currentState() -> CreatorEntitlementState {
        let storeKitEntitled = defaults.bool(forKey: IAPStore.creatorPassEntitlementKey)
        #if DEBUG
        let debugOverride = defaults.bool(forKey: Self.debugOverrideKey)
        #else
        let debugOverride = false
        #endif

        return CommunityLiteSupport.creatorEntitlementState(
            creatorPassEnabled: FeatureFlags.creatorPassEnabled,
            creatorCommunityCreationEnabled: FeatureFlags.creatorCommunityCreationEnabled,
            creatorCommunityLocalDraftEnabled: FeatureFlags.creatorCommunityLocalDraftEnabled,
            storeKitEntitled: storeKitEntitled,
            debugOverride: debugOverride
        )
    }

    #if DEBUG
    func setDebugOverrideEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.debugOverrideKey)
    }

    func isDebugOverrideEnabled() -> Bool {
        defaults.bool(forKey: Self.debugOverrideKey)
    }
    #endif
}
