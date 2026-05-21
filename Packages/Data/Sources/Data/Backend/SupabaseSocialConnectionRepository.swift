import Foundation
import Domain

public enum SupabaseSocialConnectionError: Error, Equatable, Sendable {
    case unavailable(SupabaseBackendStatus)
    case supabaseAuthSessionMissing
    case targetIsLocalOnly
    case invalidResponse(Int, String)
}

public final class SupabaseSocialSyncDiagnosticsStore: @unchecked Sendable {
    public static let storeKey = "MyDailyPhrase.backend.socialSync.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> SocialSyncDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.storeKey),
                  let diagnostics = try? decoder.decode(SocialSyncDiagnostics.self, from: data) else {
                return .localFallback
            }
            return diagnostics
        }
    }

    public func save(_ diagnostics: SocialSyncDiagnostics) {
        withLock {
            guard let data = try? encoder.encode(diagnostics) else { return }
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    public func record(
        status: SocialSyncStatus,
        error: String? = nil,
        followingCount: Int? = nil,
        followerCount: Int? = nil,
        blockedCount: Int? = nil,
        reportedTargetID: String? = nil,
        date: Date = Date()
    ) {
        let previous = load()
        save(
            SocialSyncDiagnostics(
                status: status,
                lastErrorMessage: error,
                lastSyncAt: status == .synced ? date : previous.lastSyncAt,
                lastAttemptAt: date,
                followingCount: followingCount ?? previous.followingCount,
                followerCount: followerCount ?? previous.followerCount,
                blockedCount: blockedCount ?? previous.blockedCount,
                lastReportedTargetID: reportedTargetID ?? previous.lastReportedTargetID
            )
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private struct SupabaseFollowRow: Codable, Equatable, Sendable {
    var followerUserID: String
    var followedUserID: String

    private enum CodingKeys: String, CodingKey {
        case followerUserID = "follower_user_id"
        case followedUserID = "followed_user_id"
    }
}

private struct SupabaseBlockRow: Codable, Equatable, Sendable {
    var blockerUserID: String
    var blockedUserID: String

    private enum CodingKeys: String, CodingKey {
        case blockerUserID = "blocker_user_id"
        case blockedUserID = "blocked_user_id"
    }
}

private struct SupabaseReportRow: Codable, Equatable, Sendable {
    var id: String
    var reporterUserID: String
    var targetKind: String
    var targetID: String
    var reason: String
    var note: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case reporterUserID = "reporter_user_id"
        case targetKind = "target_kind"
        case targetID = "target_id"
        case reason
        case note
    }
}

private struct SupabaseSocialProfileRow: Codable, Equatable, Sendable {
    var userID: String
    var displayName: String
    var bio: String?
    var equippedThemeID: String?
    var profileTitle: String?

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case bio
        case equippedThemeID = "equipped_theme_id"
        case profileTitle = "profile_title"
    }

    var summary: SocialUserProfileSummary {
        SocialUserProfileSummary(
            id: userID,
            displayName: displayName,
            profileTitle: profileTitle,
            equippedThemeId: equippedThemeID ?? CardDecorationCatalog.classicId,
            joinedCommunityCount: 0,
            bio: bio,
            supportsMutualDM: true,
            isLocalOnly: false
        )
    }
}

public final class SupabaseSocialConnectionRepository: SocialConnectionRepository, @unchecked Sendable {
    private let configuration: SupabaseBackendConfiguration
    private let fallback: SocialConnectionRepository
    private let httpClient: SupabaseHTTPClient
    private let diagnosticsStore: SupabaseSocialSyncDiagnosticsStore
    private let authSessionProvider: @Sendable () -> SupabaseAuthSession?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSRecursiveLock()

    private var cachedFollowingIDs: Set<String> = []
    private var cachedFollowerIDs: Set<String> = []
    private var cachedBlockedIDs: Set<String> = []
    private var cachedRecommendedProfiles: [SocialUserProfileSummary] = []

    public init(
        configuration: SupabaseBackendConfiguration,
        fallback: SocialConnectionRepository,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient(),
        diagnosticsStore: SupabaseSocialSyncDiagnosticsStore,
        authSessionProvider: @escaping @Sendable () -> SupabaseAuthSession? = { nil }
    ) {
        self.configuration = configuration
        self.fallback = fallback
        self.httpClient = httpClient
        self.diagnosticsStore = diagnosticsStore
        self.authSessionProvider = authSessionProvider
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public var mode: SocialBackendMode {
        configuration.canUseSupabase ? .supabase : .localFallback
    }

    public var isBackendEnabled: Bool {
        configuration.canUseSupabase
    }

    public func socialSyncDiagnostics() -> SocialSyncDiagnostics {
        diagnosticsStore.load()
    }

    public func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let remote = withLock { cachedRecommendedProfiles }
        if !remote.isEmpty {
            let blocked = Set(profile.blockedUserIDs).union(withLock { cachedBlockedIDs })
            let following = Set(profile.followingUserIDs).union(withLock { cachedFollowingIDs })
            return remote
                .filter { !blocked.contains($0.id) }
                .filter { !following.contains($0.id) }
        }
        return fallback.listRecommendedProfiles(for: profile)
    }

    public func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let remoteIDs = withLock { cachedFollowingIDs }
        let remoteProfiles = profiles(for: remoteIDs, fallbackProfile: profile)
        return remoteProfiles.isEmpty ? fallback.listFollowingProfiles(for: profile) : remoteProfiles
    }

    public func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let remoteIDs = withLock { cachedFollowerIDs }
        let remoteProfiles = profiles(for: remoteIDs, fallbackProfile: profile)
        return remoteProfiles.isEmpty ? fallback.listFollowerPreviewProfiles(for: profile) : remoteProfiles
    }

    public func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let mutual = withLock { cachedFollowingIDs.intersection(cachedFollowerIDs).subtracting(cachedBlockedIDs) }
        let remoteProfiles = profiles(for: mutual, fallbackProfile: profile)
        return remoteProfiles.isEmpty ? fallback.listMutualFollowProfiles(for: profile) : remoteProfiles
    }

    public func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool {
        let remoteCanDM = withLock {
            cachedFollowingIDs.contains(target.id)
                && cachedFollowerIDs.contains(target.id)
                && !cachedBlockedIDs.contains(target.id)
        }
        return remoteCanDM || fallback.canStartDirectMessage(from: profile, to: target)
    }

    public func refreshRemoteState(for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        diagnosticsStore.record(status: .syncing, error: nil)

        async let followingRows: [SupabaseFollowRow] = fetchRows(
            path: "/rest/v1/follows",
            queryItems: [
                URLQueryItem(name: "follower_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "follower_user_id,followed_user_id")
            ],
            session: session
        )
        async let followerRows: [SupabaseFollowRow] = fetchRows(
            path: "/rest/v1/follows",
            queryItems: [
                URLQueryItem(name: "followed_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "follower_user_id,followed_user_id")
            ],
            session: session
        )
        async let blockRows: [SupabaseBlockRow] = fetchRows(
            path: "/rest/v1/blocks",
            queryItems: [
                URLQueryItem(name: "blocker_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "blocker_user_id,blocked_user_id")
            ],
            session: session
        )
        async let discoverableProfiles: [SupabaseSocialProfileRow] = fetchRows(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "is_discoverable", value: "eq.true"),
                URLQueryItem(name: "select", value: "user_id,display_name,bio,equipped_theme_id,profile_title"),
                URLQueryItem(name: "limit", value: "40")
            ],
            session: session
        )

        do {
            let following = try await Set(followingRows.map(\.followedUserID))
            let followers = try await Set(followerRows.map(\.followerUserID))
            let blocked = try await Set(blockRows.map(\.blockedUserID))
            let recommended = try await discoverableProfiles
                .map(\.summary)
                .filter { $0.id != session.userID }
            updateCache(following: following, followers: followers, blocked: blocked, recommended: recommended)
            diagnosticsStore.record(
                status: .synced,
                error: nil,
                followingCount: following.count,
                followerCount: followers.count,
                blockedCount: blocked.count
            )
            return diagnosticsStore.load()
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func follow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        let targetID = try usableRemoteTargetID(targetUserID)
        guard targetID != session.userID else {
            diagnosticsStore.record(status: .failed, error: "自分自身はフォローできません")
            throw SupabaseSocialConnectionError.targetIsLocalOnly
        }
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            try await sendNoContent(
                path: "/rest/v1/follows",
                queryItems: [URLQueryItem(name: "on_conflict", value: "follower_user_id,followed_user_id")],
                method: "POST",
                body: [SupabaseFollowRow(followerUserID: session.userID, followedUserID: targetID)],
                prefer: "resolution=ignore-duplicates,return=minimal",
                session: session,
                acceptedStatusCodes: Set(200..<300).union([409])
            )
            _ = withLock { cachedFollowingIDs.insert(targetID) }
            return try await refreshRemoteState(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func unfollow(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        let targetID = try usableRemoteTargetID(targetUserID)
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            try await sendNoContent(
                path: "/rest/v1/follows",
                queryItems: [
                    URLQueryItem(name: "follower_user_id", value: "eq.\(session.userID)"),
                    URLQueryItem(name: "followed_user_id", value: "eq.\(targetID)")
                ],
                method: "DELETE",
                body: Optional<String>.none,
                prefer: nil,
                session: session
            )
            _ = withLock { cachedFollowingIDs.remove(targetID) }
            return try await refreshRemoteState(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func block(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        let targetID = try usableRemoteTargetID(targetUserID)
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            try await sendNoContent(
                path: "/rest/v1/blocks",
                queryItems: [URLQueryItem(name: "on_conflict", value: "blocker_user_id,blocked_user_id")],
                method: "POST",
                body: [SupabaseBlockRow(blockerUserID: session.userID, blockedUserID: targetID)],
                prefer: "resolution=ignore-duplicates,return=minimal",
                session: session,
                acceptedStatusCodes: Set(200..<300).union([409])
            )
            try? await sendNoContent(
                path: "/rest/v1/follows",
                queryItems: [
                    URLQueryItem(name: "follower_user_id", value: "eq.\(session.userID)"),
                    URLQueryItem(name: "followed_user_id", value: "eq.\(targetID)")
                ],
                method: "DELETE",
                body: Optional<String>.none,
                prefer: nil,
                session: session
            )
            withLock {
                cachedBlockedIDs.insert(targetID)
                cachedFollowingIDs.remove(targetID)
            }
            return try await refreshRemoteState(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func unblock(targetUserID: String, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        let targetID = try usableRemoteTargetID(targetUserID)
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            try await sendNoContent(
                path: "/rest/v1/blocks",
                queryItems: [
                    URLQueryItem(name: "blocker_user_id", value: "eq.\(session.userID)"),
                    URLQueryItem(name: "blocked_user_id", value: "eq.\(targetID)")
                ],
                method: "DELETE",
                body: Optional<String>.none,
                prefer: nil,
                session: session
            )
            _ = withLock { cachedBlockedIDs.remove(targetID) }
            return try await refreshRemoteState(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func report(targetUserID: String, reason: SocialReportReason, note: String?, for profile: UserProfile) async throws -> SocialSyncDiagnostics {
        let session = try usableSession()
        let targetID = try usableRemoteTargetID(targetUserID)
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            try await sendNoContent(
                path: "/rest/v1/reports",
                queryItems: [],
                method: "POST",
                body: [
                    SupabaseReportRow(
                        id: UUID().uuidString,
                        reporterUserID: session.userID,
                        targetKind: "user",
                        targetID: targetID,
                        reason: reason.supabaseRawValue,
                        note: Self.normalizedReportNote(note)
                    )
                ],
                prefer: "return=minimal",
                session: session
            )
            diagnosticsStore.record(
                status: .synced,
                error: nil,
                followingCount: withLock { cachedFollowingIDs.count },
                followerCount: withLock { cachedFollowerIDs.count },
                blockedCount: withLock { cachedBlockedIDs.count },
                reportedTargetID: targetID
            )
            return diagnosticsStore.load()
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error), reportedTargetID: targetID)
            throw error
        }
    }

    private func usableSession() throws -> SupabaseAuthSession {
        guard configuration.canUseSupabase else {
            diagnosticsStore.record(status: .localFallback, error: "Supabase が未設定です")
            throw SupabaseSocialConnectionError.unavailable(configuration.status)
        }
        guard let session = authSessionProvider(), session.hasUsableAccessToken() else {
            diagnosticsStore.record(status: .skippedSignedOut, error: "ローカル保存済み / Supabase認証待ち")
            throw SupabaseSocialConnectionError.supabaseAuthSessionMissing
        }
        return session
    }

    private func usableRemoteTargetID(_ targetUserID: String) throws -> String {
        let target = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: target) != nil else {
            diagnosticsStore.record(status: .localFallback, error: "ローカルプレビュー相手のためSupabase同期をスキップしました")
            throw SupabaseSocialConnectionError.targetIsLocalOnly
        }
        return target
    }

    private func fetchRows<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        session: SupabaseAuthSession
    ) async throws -> [Response] {
        let request = try makeRequest(
            path: path,
            queryItems: queryItems,
            method: "GET",
            body: Optional<String>.none,
            prefer: nil,
            session: session
        )
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseSocialConnectionError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode([Response].self, from: data)
    }

    private func sendNoContent<Body: Encodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: Body?,
        prefer: String?,
        session: SupabaseAuthSession,
        acceptedStatusCodes: Set<Int> = Set(200..<300)
    ) async throws {
        let request = try makeRequest(
            path: path,
            queryItems: queryItems,
            method: method,
            body: body,
            prefer: prefer,
            session: session
        )
        let (data, response) = try await httpClient.data(for: request)
        guard acceptedStatusCodes.contains(response.statusCode) else {
            throw SupabaseSocialConnectionError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: Body?,
        prefer: String?,
        session: SupabaseAuthSession
    ) throws -> URLRequest {
        guard let projectURL = configuration.projectURL,
              let anonKey = configuration.anonKey,
              var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseSocialConnectionError.unavailable(configuration.status)
        }
        components.path = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw SupabaseSocialConnectionError.unavailable(.invalidConfiguration)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func profiles(for ids: Set<String>, fallbackProfile: UserProfile) -> [SocialUserProfileSummary] {
        let cached = withLock { cachedRecommendedProfiles }
        let cachedByID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        let fallbackByID = Dictionary(uniqueKeysWithValues: fallbackProfile.listAllSocialSummaries().map { ($0.id, $0) })
        return ids
            .filter { !fallbackProfile.blockedUserIDs.contains($0) }
            .sorted()
            .map { id in
                cachedByID[id]
                    ?? fallbackByID[id]
                    ?? SocialUserProfileSummary(
                        id: id,
                        displayName: "プロフィールカード",
                        equippedThemeId: CardDecorationCatalog.classicId,
                        joinedCommunityCount: 0,
                        supportsMutualDM: true,
                        isLocalOnly: false
                    )
            }
    }

    private func updateCache(
        following: Set<String>,
        followers: Set<String>,
        blocked: Set<String>,
        recommended: [SocialUserProfileSummary]
    ) {
        withLock {
            cachedFollowingIDs = following
            cachedFollowerIDs = followers
            cachedBlockedIDs = blocked
            cachedRecommendedProfiles = recommended.filter { !blocked.contains($0.id) }
        }
    }

    private func readableError(_ error: Error) -> String {
        if case let SupabaseSocialConnectionError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 401, 403:
                return "HTTP \(statusCode): Social同期がRLSで拒否されました。Supabase Auth session と auth.uid() の一致を確認してください。\(String(message.prefix(140)))"
            case 404:
                return "HTTP 404: follows/blocks/reports テーブルまたはpolicyを確認してください。\(String(message.prefix(140)))"
            default:
                return "HTTP \(statusCode): Social同期に失敗しました。\(String(message.prefix(140)))"
            }
        }
        if case SupabaseSocialConnectionError.supabaseAuthSessionMissing = error {
            return "ローカル保存済み / Supabase認証待ち"
        }
        if case SupabaseSocialConnectionError.targetIsLocalOnly = error {
            return "ローカルプレビュー相手のためSupabase同期をスキップしました"
        }
        if case let SupabaseSocialConnectionError.unavailable(status) = error {
            return "Supabase が利用できません: \(status.label)"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func normalizedReportNote(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(280))
    }
}

private extension SocialReportReason {
    var supabaseRawValue: String {
        switch self {
        case .spam:
            return "spam"
        case .harassment:
            return "harassment"
        case .unsafeContent:
            return "unsafe_content"
        case .impersonation:
            return "impersonation"
        case .other:
            return "other"
        }
    }
}

private extension UserProfile {
    func listAllSocialSummaries() -> [SocialUserProfileSummary] {
        dmConversations.map {
            SocialUserProfileSummary(
                id: $0.participantUserID,
                displayName: $0.participantDisplayName,
                profileTitle: $0.participantProfileTitle,
                equippedThemeId: $0.participantDecorationID ?? CardDecorationCatalog.classicId,
                joinedCommunityCount: 0,
                supportsMutualDM: true,
                isLocalOnly: true
            )
        }
    }
}
