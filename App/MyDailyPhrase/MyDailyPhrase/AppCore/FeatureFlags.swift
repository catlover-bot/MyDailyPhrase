import Foundation
import Presentation

enum FeatureFlags {
    static let paidGachaEnabled = ReleaseFeatureAvailability.paidGachaEnabled
    static let communityEnabled = false
    static let publicCommunityEnabled = ReleaseFeatureAvailability.publicCommunityEnabled
    static let communityLiteEnabled = ReleaseFeatureAvailability.communityLiteEnabled
    static let gameCommunityEnabled = ReleaseFeatureAvailability.gameCommunityEnabled
    static let socialGraphEnabled = ReleaseFeatureAvailability.socialGraphEnabled
    static let publicUserDiscoveryEnabled = ReleaseFeatureAvailability.publicUserDiscoveryEnabled
    static let dmEnabled = ReleaseFeatureAvailability.dmEnabled
    static let publicDMEnabled = ReleaseFeatureAvailability.publicDMEnabled
    static let creatorPassEnabled = ReleaseFeatureAvailability.creatorPassEnabled
    static let creatorCommunityCreationEnabled = ReleaseFeatureAvailability.creatorCommunityCreationEnabled
    static let creatorCommunityLocalDraftEnabled = ReleaseFeatureAvailability.creatorCommunityLocalDraftEnabled
    static let externalAccountLinkingEnabled = false
    static let advancedProfileToolsEnabled = false
    static let nativeSharingEnabled = ReleaseFeatureAvailability.nativeSharingEnabled
    static let themePreviewEnabled = ReleaseFeatureAvailability.themePreviewEnabled
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
