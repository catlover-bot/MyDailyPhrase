import Foundation

public protocol SocialConnectionRepository: Sendable {
    var mode: SocialBackendMode { get }
    var isBackendEnabled: Bool { get }

    func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool
}

public extension SocialConnectionRepository {
    var mode: SocialBackendMode { .localFallback }
    var isBackendEnabled: Bool { false }
}
