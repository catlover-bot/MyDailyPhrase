import Foundation
import Domain

public enum SupabaseBackendStatus: String, Codable, Equatable, Sendable {
    case disabled
    case missingConfiguration
    case configured

    public var label: String {
        switch self {
        case .disabled:
            return "disabled"
        case .missingConfiguration:
            return "missingConfiguration"
        case .configured:
            return "configured"
        }
    }
}

public struct SupabaseBackendConfiguration: Equatable, Sendable {
    public let isEnabledConfigured: Bool
    public let projectURL: URL?
    public let anonKey: String?
    public let schemaVersion: String

    public init(
        isEnabledConfigured: Bool,
        projectURL: URL?,
        anonKey: String?,
        schemaVersion: String = "2026-05-21"
    ) {
        self.isEnabledConfigured = isEnabledConfigured
        self.projectURL = projectURL
        let trimmedKey = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.anonKey = (trimmedKey?.isEmpty == false) ? trimmedKey : nil
        self.schemaVersion = schemaVersion
    }

    public static func make(
        isEnabledConfigured: Bool,
        projectURLString: String?,
        anonKey: String?,
        schemaVersion: String = "2026-05-21"
    ) -> SupabaseBackendConfiguration {
        let trimmedURL = projectURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = trimmedURL.flatMap(URL.init(string:))
        return SupabaseBackendConfiguration(
            isEnabledConfigured: isEnabledConfigured,
            projectURL: url,
            anonKey: anonKey,
            schemaVersion: schemaVersion
        )
    }

    public var status: SupabaseBackendStatus {
        guard isEnabledConfigured else { return .disabled }
        guard projectURL != nil, anonKey != nil else { return .missingConfiguration }
        return .configured
    }

    public var canUseSupabase: Bool {
        status == .configured
    }
}

public struct BackendDiagnosticsSnapshot: Equatable, Sendable {
    public let provider: String
    public let status: SupabaseBackendStatus
    public let activeMode: SocialBackendMode
    public let projectURLHost: String?
    public let anonKeyConfigured: Bool
    public let schemaVersion: String
    public let localFallbackEnabled: Bool
    public let publicFeedEnabled: Bool
    public let commentsEnabled: Bool
    public let rankingEnabled: Bool
    public let dmPolicy: String
    public let secretsInRepository: Bool

    public init(configuration: SupabaseBackendConfiguration) {
        self.provider = "supabase"
        self.status = configuration.status
        self.activeMode = configuration.canUseSupabase ? .supabase : .localFallback
        self.projectURLHost = configuration.projectURL?.host
        self.anonKeyConfigured = configuration.anonKey != nil
        self.schemaVersion = configuration.schemaVersion
        self.localFallbackEnabled = true
        self.publicFeedEnabled = false
        self.commentsEnabled = false
        self.rankingEnabled = false
        self.dmPolicy = "mutual_follow_only"
        self.secretsInRepository = false
    }

    public var reportText: String {
        [
            "backendProvider: \(provider)",
            "backendStatus: \(status.label)",
            "activeMode: \(activeMode.rawValue)",
            "projectURLHost: \(projectURLHost ?? "未設定")",
            "anonKeyConfigured: \(anonKeyConfigured)",
            "schemaVersion: \(schemaVersion)",
            "localFallbackEnabled: \(localFallbackEnabled)",
            "publicFeedEnabled: \(publicFeedEnabled)",
            "commentsEnabled: \(commentsEnabled)",
            "rankingEnabled: \(rankingEnabled)",
            "dmPolicy: \(dmPolicy)",
            "secretsInRepository: \(secretsInRepository)"
        ].joined(separator: "\n")
    }
}

public final class DisabledSupabaseSocialConnectionRepository: SocialConnectionRepository, @unchecked Sendable {
    private let fallback: SocialConnectionRepository
    public let configuration: SupabaseBackendConfiguration

    public init(
        configuration: SupabaseBackendConfiguration,
        fallback: SocialConnectionRepository
    ) {
        self.configuration = configuration
        self.fallback = fallback
    }

    public var mode: SocialBackendMode {
        configuration.canUseSupabase ? .supabase : .localFallback
    }

    public var isBackendEnabled: Bool {
        configuration.canUseSupabase
    }

    public func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        fallback.listRecommendedProfiles(for: profile)
    }

    public func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        fallback.listFollowingProfiles(for: profile)
    }

    public func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        fallback.listFollowerPreviewProfiles(for: profile)
    }

    public func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        fallback.listMutualFollowProfiles(for: profile)
    }

    public func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool {
        fallback.canStartDirectMessage(from: profile, to: target)
    }
}
