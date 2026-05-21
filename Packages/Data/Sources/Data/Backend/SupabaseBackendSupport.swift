import Foundation
import Domain

public enum SupabaseBackendStatus: String, Codable, Equatable, Sendable {
    case disabled
    case missingConfiguration
    case invalidConfiguration
    case configured

    public var label: String {
        switch self {
        case .disabled:
            return "disabled"
        case .missingConfiguration:
            return "missingConfiguration"
        case .invalidConfiguration:
            return "invalidConfiguration"
        case .configured:
            return "configured"
        }
    }
}

public struct SupabaseBackendConfiguration: Equatable, Sendable {
    public let isEnabledConfigured: Bool
    public let projectURL: URL?
    public let isProjectURLValid: Bool
    public let anonKey: String?
    public let schemaVersion: String

    public init(
        isEnabledConfigured: Bool,
        projectURL: URL?,
        isProjectURLValid: Bool? = nil,
        anonKey: String?,
        schemaVersion: String = "2026-05-21"
    ) {
        self.isEnabledConfigured = isEnabledConfigured
        self.projectURL = projectURL
        self.isProjectURLValid = isProjectURLValid ?? Self.isValidProjectURL(projectURL)
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
        let parsedURL = trimmedURL.flatMap(URL.init(string:))
        let url = Self.isValidProjectURL(parsedURL) ? parsedURL : nil
        return SupabaseBackendConfiguration(
            isEnabledConfigured: isEnabledConfigured,
            projectURL: url,
            isProjectURLValid: trimmedURL == nil || trimmedURL?.isEmpty == true || Self.isValidProjectURL(parsedURL),
            anonKey: anonKey,
            schemaVersion: schemaVersion
        )
    }

    public var status: SupabaseBackendStatus {
        guard isEnabledConfigured else { return .disabled }
        guard isProjectURLValid else { return .invalidConfiguration }
        guard projectURL != nil, anonKey != nil else { return .missingConfiguration }
        return .configured
    }

    public var canUseSupabase: Bool {
        status == .configured
    }

    private static func isValidProjectURL(_ url: URL?) -> Bool {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host,
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
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
    public let profileSyncStatus: ProfileSyncStatus
    public let lastBackendError: String?
    public let lastProfileSyncAt: Date?
    public let backendModeLabel: String

    public init(
        configuration: SupabaseBackendConfiguration,
        profileSyncDiagnostics: ProfileSyncDiagnostics = .localFallback
    ) {
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
        self.profileSyncStatus = profileSyncDiagnostics.status
        self.lastBackendError = profileSyncDiagnostics.lastErrorMessage
        self.lastProfileSyncAt = profileSyncDiagnostics.lastSyncAt
        if activeMode == .localFallback {
            self.backendModeLabel = "localFallback"
        } else {
            switch profileSyncDiagnostics.status {
            case .synced:
                self.backendModeLabel = "supabaseAvailable"
            case .failed:
                self.backendModeLabel = "supabaseError"
            default:
                self.backendModeLabel = "supabaseConfigured"
            }
        }
    }

    public var reportText: String {
        [
            "backendProvider: \(provider)",
            "backendStatus: \(status.label)",
            "activeMode: \(activeMode.rawValue)",
            "backendMode: \(backendModeLabel)",
            "projectURLHost: \(projectURLHost ?? "未設定")",
            "anonKeyConfigured: \(anonKeyConfigured)",
            "schemaVersion: \(schemaVersion)",
            "localFallbackEnabled: \(localFallbackEnabled)",
            "publicFeedEnabled: \(publicFeedEnabled)",
            "commentsEnabled: \(commentsEnabled)",
            "rankingEnabled: \(rankingEnabled)",
            "dmPolicy: \(dmPolicy)",
            "secretsInRepository: \(secretsInRepository)",
            "profileSyncStatus: \(profileSyncStatus.rawValue)",
            "lastBackendError: \(lastBackendError ?? "なし")",
            "lastProfileSyncAt: \(lastProfileSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")"
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
