import Foundation

public protocol SocialConnectionRepository: Sendable {
    func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool
}
