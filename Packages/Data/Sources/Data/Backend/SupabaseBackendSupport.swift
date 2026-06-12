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
    public static let profilesTableName = "profiles"

    public let isEnabledConfigured: Bool
    public let projectURL: URL?
    public let isProjectURLValid: Bool
    public let anonKey: String?
    public let authEnabledConfigured: Bool
    public let appleAuthEnabledConfigured: Bool
    public let schemaVersion: String

    public init(
        isEnabledConfigured: Bool,
        projectURL: URL?,
        isProjectURLValid: Bool? = nil,
        anonKey: String?,
        authEnabledConfigured: Bool = false,
        appleAuthEnabledConfigured: Bool = false,
        schemaVersion: String = "2026-05-21"
    ) {
        self.isEnabledConfigured = isEnabledConfigured
        self.projectURL = projectURL
        self.isProjectURLValid = isProjectURLValid ?? Self.isValidProjectURL(projectURL)
        let trimmedKey = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.anonKey = (trimmedKey?.isEmpty == false) ? trimmedKey : nil
        self.authEnabledConfigured = authEnabledConfigured
        self.appleAuthEnabledConfigured = appleAuthEnabledConfigured
        self.schemaVersion = schemaVersion
    }

    public static func make(
        isEnabledConfigured: Bool,
        projectURLString: String?,
        anonKey: String?,
        authEnabledConfigured: Bool = false,
        appleAuthEnabledConfigured: Bool = false,
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
            authEnabledConfigured: authEnabledConfigured,
            appleAuthEnabledConfigured: appleAuthEnabledConfigured,
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

    public var canUseAppleAuthBridge: Bool {
        canUseSupabase && authEnabledConfigured && appleAuthEnabledConfigured
    }

    public var keyTypeLabel: String {
        guard let anonKey else { return "none" }
        if anonKey.hasPrefix("sb_publishable_") {
            return "publishable"
        }
        if anonKey.split(separator: ".").count == 3 {
            return "jwt_anon_legacy"
        }
        return "unknown"
    }

    public var keySafePrefix: String {
        guard let anonKey else { return "none" }
        if anonKey.hasPrefix("sb_publishable_") {
            return "sb_publishable"
        }
        if anonKey.split(separator: ".").count == 3 {
            return "jwt"
        }
        return String(anonKey.prefix(6))
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

public enum SupabaseAuthStatus: String, Codable, Equatable, CaseIterable, Sendable {
    case disabled
    case missingConfiguration
    case signedOut
    case signingIn
    case signedIn
    case failed
}

public struct SupabaseAuthDiagnostics: Codable, Equatable, Sendable {
    public var status: SupabaseAuthStatus
    public var supabaseUserID: String?
    public var accessTokenPresent: Bool
    public var refreshTokenPresent: Bool
    public var tokenExpiresAt: Date?
    public var lastErrorMessage: String?
    public var lastAuthAt: Date?

    public init(
        status: SupabaseAuthStatus = .disabled,
        supabaseUserID: String? = nil,
        accessTokenPresent: Bool = false,
        refreshTokenPresent: Bool = false,
        tokenExpiresAt: Date? = nil,
        lastErrorMessage: String? = nil,
        lastAuthAt: Date? = nil
    ) {
        self.status = status
        self.supabaseUserID = supabaseUserID
        self.accessTokenPresent = accessTokenPresent
        self.refreshTokenPresent = refreshTokenPresent
        self.tokenExpiresAt = tokenExpiresAt
        self.lastErrorMessage = lastErrorMessage
        self.lastAuthAt = lastAuthAt
    }

    public static let disabled = SupabaseAuthDiagnostics()
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
    public let keyType: String
    public let keySafePrefix: String
    public let profilesTableName: String
    public let connectionStatus: BackendConnectionStatus
    public let lastConnectionError: String?
    public let lastConnectionCheckedAt: Date?
    public let supabaseAuthStatus: SupabaseAuthStatus
    public let supabaseUserID: String?
    public let supabaseAccessTokenPresent: Bool
    public let supabaseRefreshTokenPresent: Bool
    public let supabaseTokenExpiresAt: Date?
    public let lastSupabaseAuthError: String?
    public let socialSyncStatus: SocialSyncStatus
    public let lastSocialSyncError: String?
    public let lastSocialSyncAt: Date?
    public let socialFollowingCount: Int?
    public let socialFollowerCount: Int?
    public let socialBlockedCount: Int?
    public let lastSocialReportedTargetID: String?
    public let communitySyncStatus: CommunitySyncStatus
    public let membershipSyncStatus: CommunitySyncStatus
    public let lastCommunitySyncError: String?
    public let lastCommunitySyncAt: Date?
    public let joinedCommunityCount: Int?
    public let recommendedCommunityCount: Int?
    public let communityMemberCount: Int?
    public let lastCommunityID: String?
    public let communityRepositoryMode: SocialBackendMode
    public let dmSyncStatus: DMSyncStatus
    public let lastDMSyncError: String?
    public let lastDMSyncAt: Date?
    public let dmThreadCount: Int?
    public let dmMessageCount: Int?
    public let lastDMThreadID: String?
    public let lastDMPeerUserID: String?
    public let dmRepositoryMode: SocialBackendMode

    public init(
        configuration: SupabaseBackendConfiguration,
        profileSyncDiagnostics: ProfileSyncDiagnostics = .localFallback,
        connectionDiagnostics: BackendConnectionDiagnostics = .localFallback,
        authDiagnostics: SupabaseAuthDiagnostics = .disabled,
        socialSyncDiagnostics: SocialSyncDiagnostics = .localFallback,
        communitySyncDiagnostics: CommunitySyncDiagnostics = .localFallback,
        dmSyncDiagnostics: DMSyncDiagnostics = .localFallback
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
        self.keyType = configuration.keyTypeLabel
        self.keySafePrefix = configuration.keySafePrefix
        self.profilesTableName = SupabaseBackendConfiguration.profilesTableName
        self.connectionStatus = connectionDiagnostics.status
        self.lastConnectionError = connectionDiagnostics.lastErrorMessage
        self.lastConnectionCheckedAt = connectionDiagnostics.lastCheckedAt
        self.supabaseAuthStatus = authDiagnostics.status
        self.supabaseUserID = authDiagnostics.supabaseUserID
        self.supabaseAccessTokenPresent = authDiagnostics.accessTokenPresent
        self.supabaseRefreshTokenPresent = authDiagnostics.refreshTokenPresent
        self.supabaseTokenExpiresAt = authDiagnostics.tokenExpiresAt
        self.lastSupabaseAuthError = authDiagnostics.lastErrorMessage
        self.socialSyncStatus = socialSyncDiagnostics.status
        self.lastSocialSyncError = socialSyncDiagnostics.lastErrorMessage
        self.lastSocialSyncAt = socialSyncDiagnostics.lastSyncAt
        self.socialFollowingCount = socialSyncDiagnostics.followingCount
        self.socialFollowerCount = socialSyncDiagnostics.followerCount
        self.socialBlockedCount = socialSyncDiagnostics.blockedCount
        self.lastSocialReportedTargetID = socialSyncDiagnostics.lastReportedTargetID
        self.communitySyncStatus = communitySyncDiagnostics.status
        self.membershipSyncStatus = communitySyncDiagnostics.membershipStatus
        self.lastCommunitySyncError = communitySyncDiagnostics.lastErrorMessage
        self.lastCommunitySyncAt = communitySyncDiagnostics.lastSyncAt
        self.joinedCommunityCount = communitySyncDiagnostics.joinedCommunityCount
        self.recommendedCommunityCount = communitySyncDiagnostics.recommendedCommunityCount
        self.communityMemberCount = communitySyncDiagnostics.memberCount
        self.lastCommunityID = communitySyncDiagnostics.lastCommunityID
        self.communityRepositoryMode = configuration.canUseSupabase ? .supabase : .localFallback
        self.dmSyncStatus = dmSyncDiagnostics.status
        self.lastDMSyncError = dmSyncDiagnostics.lastErrorMessage
        self.lastDMSyncAt = dmSyncDiagnostics.lastSyncAt
        self.dmThreadCount = dmSyncDiagnostics.threadCount
        self.dmMessageCount = dmSyncDiagnostics.messageCount
        self.lastDMThreadID = dmSyncDiagnostics.lastThreadID
        self.lastDMPeerUserID = dmSyncDiagnostics.lastPeerUserID
        self.dmRepositoryMode = configuration.canUseSupabase ? .supabase : .localFallback
        if activeMode == .localFallback {
            self.backendModeLabel = "localFallback"
        } else {
            switch (connectionDiagnostics.status, profileSyncDiagnostics.status, communitySyncDiagnostics.status, dmSyncDiagnostics.status) {
            case (.reachable, _, _, _):
                self.backendModeLabel = "supabaseAvailable"
            case (.failed, _, _, _), (_, .failed, _, _), (_, _, .failed, _), (_, _, _, .failed):
                self.backendModeLabel = "supabaseError"
            case (_, .synced, _, _), (_, _, .synced, _), (_, _, _, .synced):
                self.backendModeLabel = "supabaseAvailable"
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
            "keyType: \(keyType)",
            "keyPrefix: \(keySafePrefix)",
            "schemaVersion: \(schemaVersion)",
            "profilesTableName: \(profilesTableName)",
            "connectionStatus: \(connectionStatus.rawValue)",
            "lastConnectionError: \(lastConnectionError ?? "なし")",
            "lastConnectionCheckedAt: \(lastConnectionCheckedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "supabaseAuthStatus: \(supabaseAuthStatus.rawValue)",
            "supabaseUserId: \(supabaseUserID ?? "なし")",
            "supabaseAccessTokenPresent: \(supabaseAccessTokenPresent)",
            "supabaseRefreshTokenPresent: \(supabaseRefreshTokenPresent)",
            "supabaseTokenExpiresAt: \(supabaseTokenExpiresAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "lastSupabaseAuthError: \(lastSupabaseAuthError ?? "なし")",
            "localFallbackEnabled: \(localFallbackEnabled)",
            "publicFeedEnabled: \(publicFeedEnabled)",
            "commentsEnabled: \(commentsEnabled)",
            "rankingEnabled: \(rankingEnabled)",
            "dmPolicy: \(dmPolicy)",
            "secretsInRepository: \(secretsInRepository)",
            "profileSyncStatus: \(profileSyncStatus.rawValue)",
            "lastBackendError: \(lastBackendError ?? "なし")",
            "lastProfileSyncAt: \(lastProfileSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "socialSyncStatus: \(socialSyncStatus.rawValue)",
            "lastSocialSyncError: \(lastSocialSyncError ?? "なし")",
            "lastSocialSyncAt: \(lastSocialSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "socialFollowingCount: \(socialFollowingCount.map(String.init) ?? "なし")",
            "socialFollowerCount: \(socialFollowerCount.map(String.init) ?? "なし")",
            "socialBlockedCount: \(socialBlockedCount.map(String.init) ?? "なし")",
            "lastSocialReportedTargetID: \(lastSocialReportedTargetID ?? "なし")",
            "communitySyncStatus: \(communitySyncStatus.rawValue)",
            "membershipSyncStatus: \(membershipSyncStatus.rawValue)",
            "communityRepositoryMode: \(communityRepositoryMode.rawValue)",
            "lastCommunitySyncError: \(lastCommunitySyncError ?? "なし")",
            "lastCommunitySyncAt: \(lastCommunitySyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "joinedCommunityCount: \(joinedCommunityCount.map(String.init) ?? "なし")",
            "recommendedCommunityCount: \(recommendedCommunityCount.map(String.init) ?? "なし")",
            "communityMemberCount: \(communityMemberCount.map(String.init) ?? "なし")",
            "lastCommunityID: \(lastCommunityID ?? "なし")",
            "dmSyncStatus: \(dmSyncStatus.rawValue)",
            "dmRepositoryMode: \(dmRepositoryMode.rawValue)",
            "lastDMSyncError: \(lastDMSyncError ?? "なし")",
            "lastDMSyncAt: \(lastDMSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし")",
            "dmThreadCount: \(dmThreadCount.map(String.init) ?? "なし")",
            "dmMessageCount: \(dmMessageCount.map(String.init) ?? "なし")",
            "lastDMThreadID: \(lastDMThreadID ?? "なし")",
            "lastDMPeerUserID: \(lastDMPeerUserID ?? "なし")"
        ].joined(separator: "\n")
    }
}

public final class SupabaseConnectionDiagnosticsStore: @unchecked Sendable {
    public static let storeKey = "MyDailyPhrase.backend.connection.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> BackendConnectionDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.storeKey),
                  let diagnostics = try? decoder.decode(BackendConnectionDiagnostics.self, from: data) else {
                return .localFallback
            }
            return diagnostics
        }
    }

    public func save(_ diagnostics: BackendConnectionDiagnostics) {
        withLock {
            guard let data = try? encoder.encode(diagnostics) else { return }
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    public func record(
        status: BackendConnectionStatus,
        error: String? = nil,
        date: Date = Date()
    ) {
        save(
            BackendConnectionDiagnostics(
                status: status,
                lastErrorMessage: error,
                lastCheckedAt: date
            )
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

public struct SupabaseConnectionTestResult: Equatable, Sendable {
    public let diagnostics: BackendConnectionDiagnostics
    public let tableName: String
    public let host: String?
    public let keyType: String

    public init(
        diagnostics: BackendConnectionDiagnostics,
        tableName: String,
        host: String?,
        keyType: String
    ) {
        self.diagnostics = diagnostics
        self.tableName = tableName
        self.host = host
        self.keyType = keyType
    }
}

public struct SupabaseBackendConnectionTester: Sendable {
    private let configuration: SupabaseBackendConfiguration
    private let httpClient: SupabaseHTTPClient

    public init(
        configuration: SupabaseBackendConfiguration,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    public func testProfilesTableRead() async -> SupabaseConnectionTestResult {
        let tableName = SupabaseBackendConfiguration.profilesTableName
        guard configuration.isEnabledConfigured else {
            return result(status: .localFallback, error: "Supabase は無効です")
        }
        guard configuration.status != .invalidConfiguration else {
            return result(status: .failed, error: "Supabase URL が不正です。https://...supabase.co を確認してください。")
        }
        guard configuration.canUseSupabase,
              let projectURL = configuration.projectURL,
              let anonKey = configuration.anonKey,
              var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else {
            return result(status: .failed, error: "Supabase URL または publishable key が未設定です。")
        }

        components.path = "/rest/v1/\(tableName)"
        components.queryItems = [
            URLQueryItem(name: "select", value: "user_id"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else {
            return result(status: .failed, error: "Supabase URL を組み立てられませんでした。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await httpClient.data(for: request)
            if (200..<300).contains(response.statusCode) {
                return result(status: .reachable, error: nil)
            }
            return result(status: .failed, error: readableError(statusCode: response.statusCode, data: data, tableName: tableName))
        } catch {
            return result(status: .failed, error: "ネットワーク接続に失敗しました: \(error.localizedDescription)")
        }
    }

    private func result(status: BackendConnectionStatus, error: String?) -> SupabaseConnectionTestResult {
        SupabaseConnectionTestResult(
            diagnostics: BackendConnectionDiagnostics(
                status: status,
                lastErrorMessage: error,
                lastCheckedAt: Date()
            ),
            tableName: SupabaseBackendConfiguration.profilesTableName,
            host: configuration.projectURL?.host,
            keyType: configuration.keyTypeLabel
        )
    }

    private func readableError(statusCode: Int, data: Data, tableName: String) -> String {
        let body = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let clippedBody = String(body.prefix(220))
        switch statusCode {
        case 401, 403:
            return "HTTP \(statusCode): 認証またはRLSで拒否されました。RLS policy、user_id、publishable key、テーブル名 \(tableName) を確認してください。\(clippedBody)"
        case 404:
            return "HTTP 404: テーブル \(tableName) が見つかりません。schema.sql の適用とテーブル名を確認してください。\(clippedBody)"
        default:
            return "HTTP \(statusCode): Supabase接続テストに失敗しました。\(clippedBody)"
        }
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
