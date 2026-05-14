import Presentation

enum FeatureFlags {
    static let paidGachaEnabled = ReleaseFeatureAvailability.paidGachaEnabled
    static let communityEnabled = false
    static let publicCommunityEnabled = ReleaseFeatureAvailability.publicCommunityEnabled
    static let communityLiteEnabled = ReleaseFeatureAvailability.communityLiteEnabled
    static let externalAccountLinkingEnabled = false
    static let advancedProfileToolsEnabled = false
    static let nativeSharingEnabled = ReleaseFeatureAvailability.nativeSharingEnabled
    static let themePreviewEnabled = ReleaseFeatureAvailability.themePreviewEnabled
}
