import Foundation

public protocol SocialConnectionRepository: Sendable {
    var mode: SocialBackendMode { get }
    var isBackendEnabled: Bool { get }

    func socialSyncDiagnostics() -> SocialSyncDiagnostics
    func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary]
    func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool
    func refreshRemoteState(for profile: UserProfile) async throws -> SocialSyncDiagnostics
    func follow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics
    func unfollow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics
    func block(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics
    func unblock(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics
    func report(targetUserID: String, reason: SocialReportReason, note: String?, for profile: UserProfile) async throws -> SocialSyncDiagnostics
}

public extension SocialConnectionRepository {
    var mode: SocialBackendMode { .localFallback }
    var isBackendEnabled: Bool { false }

    func socialSyncDiagnostics() -> SocialSyncDiagnostics {
        .localFallback
    }

    func refreshRemoteState(for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }

    func follow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }

    func unfollow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }

    func block(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }

    func unblock(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }

    func report(targetUserID: String, reason: SocialReportReason, note: String?, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        .localFallback
    }
}
