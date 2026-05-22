import Foundation
import Domain

public enum SupabaseCommunityRepositoryError: Error, Equatable, Sendable {
    case unavailable(SupabaseBackendStatus)
    case supabaseAuthSessionMissing
    case targetIsLocalOnly
    case creationNotAllowed
    case invalidResponse(Int, String)
}

public final class SupabaseCommunitySyncDiagnosticsStore: @unchecked Sendable {
    public static let storeKey = "MyDailyPhrase.backend.communitySync.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> CommunitySyncDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.storeKey),
                  let diagnostics = try? decoder.decode(CommunitySyncDiagnostics.self, from: data) else {
                return .localFallback
            }
            return diagnostics
        }
    }

    public func save(_ diagnostics: CommunitySyncDiagnostics) {
        withLock {
            guard let data = try? encoder.encode(diagnostics) else { return }
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    public func record(
        status: CommunitySyncStatus,
        membershipStatus: CommunitySyncStatus? = nil,
        error: String? = nil,
        joinedCommunityCount: Int? = nil,
        recommendedCommunityCount: Int? = nil,
        memberCount: Int? = nil,
        communityID: String? = nil,
        date: Date = Date()
    ) {
        let previous = load()
        save(
            CommunitySyncDiagnostics(
                status: status,
                membershipStatus: membershipStatus ?? previous.membershipStatus,
                lastErrorMessage: error,
                lastSyncAt: status == .synced ? date : previous.lastSyncAt,
                lastAttemptAt: date,
                joinedCommunityCount: joinedCommunityCount ?? previous.joinedCommunityCount,
                recommendedCommunityCount: recommendedCommunityCount ?? previous.recommendedCommunityCount,
                memberCount: memberCount ?? previous.memberCount,
                lastCommunityID: communityID ?? previous.lastCommunityID
            )
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private struct SupabaseCommunityRow: Codable, Equatable, Sendable {
    var id: String
    var creatorUserID: String?
    var name: String
    var description: String
    var category: String
    var emoji: String
    var visibility: String
    var promptSchedule: String
    var promptPolicy: CommunityPromptPolicy?
    var promptPacks: [String]
    var themeDecorationID: String?
    var allowedTags: [String]
    var blockedWords: [String]
    var requiresCreatorPassToCreate: Bool
    var isOfficialPreset: Bool
    var createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case creatorUserID = "creator_user_id"
        case name
        case description
        case category
        case emoji
        case visibility
        case promptSchedule = "prompt_schedule"
        case promptPolicy = "prompt_policy"
        case promptPacks = "prompt_packs"
        case themeDecorationID = "theme_decoration_id"
        case allowedTags = "allowed_tags"
        case blockedWords = "blocked_words"
        case requiresCreatorPassToCreate = "requires_creator_pass_to_create"
        case isOfficialPreset = "is_official_preset"
        case createdAt = "created_at"
    }

    init(community: CommunityTemplate, creatorUserID: String? = nil) {
        var community = community
        community.normalize()
        self.id = UUID(uuidString: community.id)?.uuidString ?? UUID().uuidString
        self.creatorUserID = creatorUserID ?? community.creatorId
        self.name = community.name
        self.description = community.description
        self.category = community.category.rawValue
        self.emoji = community.emoji
        self.visibility = community.visibility.supabaseRawValue
        self.promptSchedule = community.promptSchedule.rawValue
        self.promptPolicy = community.promptPolicy
        self.promptPacks = community.promptPacks
        self.themeDecorationID = community.themeDecorationId
        self.allowedTags = community.allowedTags
        self.blockedWords = community.blockedWords
        self.requiresCreatorPassToCreate = community.requiresCreatorPassToCreate
        self.isOfficialPreset = community.isOfficialPreset
        self.createdAt = Self.isoFormatter.string(from: community.createdAt)
    }

    func community(joinedCommunityIDs: Set<String>, joinedAtByCommunityID: [String: Date]) -> CommunityTemplate {
        var community = CommunityTemplate(
            id: id,
            name: name,
            description: description,
            category: CommunityCategory(rawValue: category) ?? .games,
            emoji: emoji,
            createdAt: createdAt.flatMap(Self.parseDate) ?? Date(),
            creatorId: creatorUserID,
            visibility: CommunityVisibility(supabaseRawValue: visibility),
            promptPolicy: promptPolicy ?? CommunityPromptPolicy(),
            promptSchedule: CommunityPromptSchedule(rawValue: promptSchedule) ?? .daily,
            promptPacks: promptPacks,
            themeDecorationId: themeDecorationID,
            allowedTags: allowedTags,
            blockedWords: blockedWords,
            isOfficialPreset: isOfficialPreset,
            requiresCreatorPassToCreate: requiresCreatorPassToCreate,
            isJoined: joinedCommunityIDs.contains(id),
            joinedAt: joinedAtByCommunityID[id]
        )
        community.normalize()
        return community
    }

    private static let isoFormatter = ISO8601DateFormatter()

    private static func parseDate(_ value: String) -> Date? {
        isoFormatter.date(from: value)
    }
}

private struct SupabaseMembershipRow: Codable, Equatable, Sendable {
    var communityID: String
    var userID: String
    var memberRole: String
    var joinedAt: String?

    private enum CodingKeys: String, CodingKey {
        case communityID = "community_id"
        case userID = "user_id"
        case memberRole = "member_role"
        case joinedAt = "joined_at"
    }

    init(
        communityID: String,
        userID: String,
        memberRole: String = "member",
        joinedAt: String? = nil
    ) {
        self.communityID = communityID
        self.userID = userID
        self.memberRole = memberRole
        self.joinedAt = joinedAt
    }

    var status: CommunityMembershipStatus {
        CommunityMembershipStatus(rawValue: memberRole) ?? .member
    }

    var summary: CommunityMemberSummary {
        CommunityMemberSummary(
            userID: userID,
            role: status,
            joinedAt: joinedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

public final class SupabaseCommunityRepository: CommunityRepository, @unchecked Sendable {
    private let configuration: SupabaseBackendConfiguration
    private let fallback: CommunityRepository
    private let httpClient: SupabaseHTTPClient
    private let diagnosticsStore: SupabaseCommunitySyncDiagnosticsStore
    private let authSessionProvider: @Sendable () -> SupabaseAuthSession?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSRecursiveLock()

    private var cachedRemoteCommunities: [CommunityTemplate] = []
    private var cachedMemberships: [String: CommunityMembershipStatus] = [:]

    public init(
        configuration: SupabaseBackendConfiguration,
        fallback: CommunityRepository,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient(),
        diagnosticsStore: SupabaseCommunitySyncDiagnosticsStore,
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

    public func communitySyncDiagnostics() -> CommunitySyncDiagnostics {
        diagnosticsStore.load()
    }

    public func listCommunities() -> [CommunityTemplate] {
        let remote = withLock { cachedRemoteCommunities }
        guard !remote.isEmpty else {
            return fallback.listCommunities()
        }
        let local = fallback.listCommunities()
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for community in remote {
            merged[community.id] = community
        }
        return Array(merged.values)
    }

    public func community(id: String) -> CommunityTemplate? {
        withLock { cachedRemoteCommunities.first { $0.id == id } } ?? fallback.community(id: id)
    }

    public func saveCommunity(_ community: CommunityTemplate) {
        fallback.saveCommunity(community)
    }

    public func deleteCommunity(id: String) {
        fallback.deleteCommunity(id: id)
    }

    public func setJoined(_ isJoined: Bool, communityId: String, joinedAt: Date?) {
        fallback.setJoined(isJoined, communityId: communityId, joinedAt: joinedAt)
    }

    public func listResponses() -> [CommunityResponse] {
        fallback.listResponses()
    }

    public func response(communityId: String, promptKey: String) -> CommunityResponse? {
        fallback.response(communityId: communityId, promptKey: promptKey)
    }

    public func saveResponse(_ response: CommunityResponse) {
        fallback.saveResponse(response)
    }

    public func deleteResponse(communityId: String, promptKey: String) {
        fallback.deleteResponse(communityId: communityId, promptKey: promptKey)
    }

    public func refreshRemoteCommunities(for profile: UserProfile) async throws -> CommunitySyncDiagnostics {
        let session = try usableSession()
        diagnosticsStore.record(status: .syncing, membershipStatus: .syncing, error: nil)
        do {
            async let membershipRows: [SupabaseMembershipRow] = fetchRows(
                path: "/rest/v1/memberships",
                queryItems: [
                    URLQueryItem(name: "user_id", value: "eq.\(session.userID)"),
                    URLQueryItem(name: "select", value: "community_id,user_id,member_role,joined_at")
                ],
                session: session
            )
            async let communityRows: [SupabaseCommunityRow] = fetchRows(
                path: "/rest/v1/communities",
                queryItems: [
                    URLQueryItem(name: "select", value: Self.communitySelectColumns),
                    URLQueryItem(name: "limit", value: "60")
                ],
                session: session
            )
            let memberships = try await membershipRows
            let joinedIDs = Set(memberships.map(\.communityID))
            let joinedAtByID = Dictionary(uniqueKeysWithValues: memberships.map { row in
                (row.communityID, row.joinedAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
            })
            let communities = try await communityRows.map {
                $0.community(joinedCommunityIDs: joinedIDs, joinedAtByCommunityID: joinedAtByID)
            }
            updateCache(communities: communities, memberships: memberships)
            diagnosticsStore.record(
                status: .synced,
                membershipStatus: .synced,
                error: nil,
                joinedCommunityCount: joinedIDs.count,
                recommendedCommunityCount: communities.filter { !$0.isJoined }.count
            )
            return diagnosticsStore.load()
        } catch {
            diagnosticsStore.record(status: .failed, membershipStatus: .failed, error: readableError(error))
            throw error
        }
    }

    public func fetchCommunityDetail(id: String, for profile: UserProfile) async throws -> CommunityTemplate? {
        let session = try usableSession()
        let communityID = try usableRemoteCommunityID(id)
        let rows: [SupabaseCommunityRow] = try await fetchRows(
            path: "/rest/v1/communities",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(communityID)"),
                URLQueryItem(name: "select", value: Self.communitySelectColumns),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        let status = try? await membershipStatus(communityID: communityID, for: profile)
        let joined = status != nil && status != .notJoined && status != .localFallback
        return rows.first?.community(
            joinedCommunityIDs: joined ? [communityID] : [],
            joinedAtByCommunityID: [:]
        )
    }

    public func createCommunity(_ community: CommunityTemplate, creatorProfile: UserProfile, canCreate: Bool) async throws -> CommunityTemplate {
        guard canCreate else {
            diagnosticsStore.record(status: .failed, error: "コミュニティ作成権限がありません")
            throw SupabaseCommunityRepositoryError.creationNotAllowed
        }
        let session = try usableSession()
        var localCommunity = community
        if UUID(uuidString: localCommunity.id) == nil {
            localCommunity.id = UUID().uuidString
        }
        localCommunity.creatorId = session.userID
        localCommunity.creatorDisplayName = creatorProfile.displayName
        localCommunity.isJoined = true
        localCommunity.joinedAt = localCommunity.joinedAt ?? Date()
        localCommunity.normalize()
        fallback.saveCommunity(localCommunity)
        diagnosticsStore.record(status: .syncing, membershipStatus: .syncing, error: nil, communityID: localCommunity.id)
        do {
            try await sendNoContent(
                path: "/rest/v1/communities",
                queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
                method: "POST",
                body: [SupabaseCommunityRow(community: localCommunity, creatorUserID: session.userID)],
                prefer: "resolution=merge-duplicates,return=minimal",
                session: session
            )
            try await joinMembership(communityID: localCommunity.id, session: session)
            _ = try await refreshRemoteCommunities(for: creatorProfile)
            return localCommunity
        } catch {
            diagnosticsStore.record(status: .failed, membershipStatus: .failed, error: readableError(error), communityID: localCommunity.id)
            throw error
        }
    }

    public func updateCommunity(_ community: CommunityTemplate, actorProfile: UserProfile, canManageAsAdmin: Bool) async throws -> CommunityTemplate {
        let session = try usableSession()
        let communityID = try usableRemoteCommunityID(community.id)
        var localCommunity = community
        localCommunity.normalize()
        fallback.saveCommunity(localCommunity)
        diagnosticsStore.record(status: .syncing, error: nil, communityID: communityID)
        do {
            try await sendNoContent(
                path: "/rest/v1/communities",
                queryItems: [
                    URLQueryItem(name: "id", value: "eq.\(communityID)"),
                    URLQueryItem(name: "creator_user_id", value: "eq.\(session.userID)")
                ],
                method: "PATCH",
                body: SupabaseCommunityRow(community: localCommunity, creatorUserID: session.userID),
                prefer: "return=minimal",
                session: session
            )
            _ = try await refreshRemoteCommunities(for: actorProfile)
            return localCommunity
        } catch {
            let prefix = canManageAsAdmin ? "管理者プレビューでもRLS上は自分が作成したコミュニティのみ更新できます。 " : ""
            diagnosticsStore.record(status: .failed, error: prefix + readableError(error), communityID: communityID)
            throw error
        }
    }

    public func joinCommunity(id: String, for profile: UserProfile) async throws -> CommunitySyncDiagnostics {
        let session = try usableSession()
        let communityID = try usableRemoteCommunityID(id)
        fallback.setJoined(true, communityId: communityID, joinedAt: Date())
        diagnosticsStore.record(status: .syncing, membershipStatus: .syncing, error: nil, communityID: communityID)
        do {
            try await joinMembership(communityID: communityID, session: session)
            return try await refreshRemoteCommunities(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, membershipStatus: .failed, error: readableError(error), communityID: communityID)
            throw error
        }
    }

    public func leaveCommunity(id: String, for profile: UserProfile) async throws -> CommunitySyncDiagnostics {
        let session = try usableSession()
        let communityID = try usableRemoteCommunityID(id)
        fallback.setJoined(false, communityId: communityID, joinedAt: nil)
        diagnosticsStore.record(status: .syncing, membershipStatus: .syncing, error: nil, communityID: communityID)
        do {
            try await sendNoContent(
                path: "/rest/v1/memberships",
                queryItems: [
                    URLQueryItem(name: "community_id", value: "eq.\(communityID)"),
                    URLQueryItem(name: "user_id", value: "eq.\(session.userID)")
                ],
                method: "DELETE",
                body: Optional<String>.none,
                prefer: nil,
                session: session
            )
            return try await refreshRemoteCommunities(for: profile)
        } catch {
            diagnosticsStore.record(status: .failed, membershipStatus: .failed, error: readableError(error), communityID: communityID)
            throw error
        }
    }

    public func fetchMembers(communityID: String, for profile: UserProfile) async throws -> [CommunityMemberSummary] {
        let session = try usableSession()
        let remoteCommunityID = try usableRemoteCommunityID(communityID)
        do {
            let rows: [SupabaseMembershipRow] = try await fetchRows(
                path: "/rest/v1/memberships",
                queryItems: [
                    URLQueryItem(name: "community_id", value: "eq.\(remoteCommunityID)"),
                    URLQueryItem(name: "select", value: "community_id,user_id,member_role,joined_at")
                ],
                session: session
            )
            diagnosticsStore.record(status: .synced, membershipStatus: .synced, error: nil, memberCount: rows.count, communityID: remoteCommunityID)
            return rows.map(\.summary)
        } catch {
            diagnosticsStore.record(status: .failed, membershipStatus: .failed, error: readableError(error), communityID: remoteCommunityID)
            throw error
        }
    }

    public func membershipStatus(communityID: String, for profile: UserProfile) async throws -> CommunityMembershipStatus {
        let session = try usableSession()
        let remoteCommunityID = try usableRemoteCommunityID(communityID)
        let rows: [SupabaseMembershipRow] = try await fetchRows(
            path: "/rest/v1/memberships",
            queryItems: [
                URLQueryItem(name: "community_id", value: "eq.\(remoteCommunityID)"),
                URLQueryItem(name: "user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "community_id,user_id,member_role,joined_at"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        return rows.first?.status ?? .notJoined
    }

    private func usableSession() throws -> SupabaseAuthSession {
        guard configuration.canUseSupabase else {
            diagnosticsStore.record(status: .localFallback, membershipStatus: .localFallback, error: "Supabase が未設定です")
            throw SupabaseCommunityRepositoryError.unavailable(configuration.status)
        }
        guard let session = authSessionProvider(), session.hasUsableAccessToken() else {
            diagnosticsStore.record(status: .skippedSignedOut, membershipStatus: .skippedSignedOut, error: "ローカル保存済み / Supabase認証待ち")
            throw SupabaseCommunityRepositoryError.supabaseAuthSessionMissing
        }
        return session
    }

    private func usableRemoteCommunityID(_ id: String) throws -> String {
        let value = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: value) != nil else {
            diagnosticsStore.record(status: .localFallback, error: "ローカルコミュニティのためSupabase同期をスキップしました", communityID: value)
            throw SupabaseCommunityRepositoryError.targetIsLocalOnly
        }
        return value
    }

    private func joinMembership(communityID: String, session: SupabaseAuthSession) async throws {
        try await sendNoContent(
            path: "/rest/v1/memberships",
            queryItems: [URLQueryItem(name: "on_conflict", value: "community_id,user_id")],
            method: "POST",
            body: [SupabaseMembershipRow(communityID: communityID, userID: session.userID)],
            prefer: "resolution=ignore-duplicates,return=minimal",
            session: session,
            acceptedStatusCodes: Set(200..<300).union([409])
        )
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
            throw SupabaseCommunityRepositoryError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
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
            throw SupabaseCommunityRepositoryError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
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
            throw SupabaseCommunityRepositoryError.unavailable(configuration.status)
        }
        components.path = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw SupabaseCommunityRepositoryError.unavailable(.invalidConfiguration)
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

    private func updateCache(communities: [CommunityTemplate], memberships: [SupabaseMembershipRow]) {
        let membershipStatuses = Dictionary(uniqueKeysWithValues: memberships.map { ($0.communityID, $0.status) })
        withLock {
            cachedRemoteCommunities = communities
            cachedMemberships = membershipStatuses
        }
    }

    private func readableError(_ error: Error) -> String {
        if case let SupabaseCommunityRepositoryError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 401, 403:
                return "HTTP \(statusCode): Community同期がRLSで拒否されました。Supabase Auth session と auth.uid() の一致を確認してください。\(String(message.prefix(140)))"
            case 404:
                return "HTTP 404: communities/memberships テーブルまたはpolicyを確認してください。\(String(message.prefix(140)))"
            default:
                return "HTTP \(statusCode): Community同期に失敗しました。\(String(message.prefix(140)))"
            }
        }
        if case SupabaseCommunityRepositoryError.supabaseAuthSessionMissing = error {
            return "ローカル保存済み / Supabase認証待ち"
        }
        if case SupabaseCommunityRepositoryError.targetIsLocalOnly = error {
            return "ローカルコミュニティのためSupabase同期をスキップしました"
        }
        if case SupabaseCommunityRepositoryError.creationNotAllowed = error {
            return "コミュニティ作成権限がありません"
        }
        if case let SupabaseCommunityRepositoryError.unavailable(status) = error {
            return "Supabase が利用できません: \(status.label)"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static let communitySelectColumns = [
        "id",
        "creator_user_id",
        "name",
        "description",
        "category",
        "emoji",
        "visibility",
        "prompt_schedule",
        "prompt_policy",
        "prompt_packs",
        "theme_decoration_id",
        "allowed_tags",
        "blocked_words",
        "requires_creator_pass_to_create",
        "is_official_preset",
        "created_at"
    ].joined(separator: ",")
}

private extension CommunityVisibility {
    var supabaseRawValue: String {
        switch self {
        case .localOnly:
            return "local_only"
        case .inviteOnly:
            return "invite_only"
        case .publicDisabled:
            return "public_disabled"
        }
    }

    init(supabaseRawValue: String) {
        switch supabaseRawValue {
        case "local_only":
            self = .localOnly
        case "public_disabled":
            self = .publicDisabled
        default:
            self = .inviteOnly
        }
    }
}
