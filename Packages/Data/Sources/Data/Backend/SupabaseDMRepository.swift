import Foundation
import Domain

public enum SupabaseDMRepositoryError: Error, Equatable, Sendable {
    case unavailable(SupabaseBackendStatus)
    case supabaseAuthSessionMissing
    case targetIsLocalOnly
    case notMutualFollow
    case blockedUser
    case emptyMessage
    case invalidResponse(Int, String)
    case emptyResponse
}

public final class SupabaseDMSyncDiagnosticsStore: @unchecked Sendable {
    public static let storeKey = "MyDailyPhrase.backend.dmSync.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> DMSyncDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.storeKey),
                  let diagnostics = try? decoder.decode(DMSyncDiagnostics.self, from: data) else {
                return .localFallback
            }
            return diagnostics
        }
    }

    public func save(_ diagnostics: DMSyncDiagnostics) {
        withLock {
            guard let data = try? encoder.encode(diagnostics) else { return }
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    public func record(
        status: DMSyncStatus,
        error: String? = nil,
        threadCount: Int? = nil,
        messageCount: Int? = nil,
        threadID: String? = nil,
        peerUserID: String? = nil,
        date: Date = Date()
    ) {
        let previous = load()
        save(
            DMSyncDiagnostics(
                status: status,
                lastErrorMessage: error,
                lastSyncAt: status == .synced ? date : previous.lastSyncAt,
                lastAttemptAt: date,
                threadCount: threadCount ?? previous.threadCount,
                messageCount: messageCount ?? previous.messageCount,
                lastThreadID: threadID ?? previous.lastThreadID,
                lastPeerUserID: peerUserID ?? previous.lastPeerUserID
            )
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private struct SupabaseDMThreadRow: Codable, Equatable, Sendable {
    var id: String
    var userAID: String
    var userBID: String
    var updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case userAID = "user_a_id"
        case userBID = "user_b_id"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, userAID: String, userBID: String, updatedAt: String? = nil) {
        self.id = id
        self.userAID = userAID
        self.userBID = userBID
        self.updatedAt = updatedAt
    }

    func peerID(for userID: String) -> String {
        userAID == userID ? userBID : userAID
    }
}

private struct SupabaseDMMessageRow: Codable, Equatable, Sendable {
    var id: String
    var threadID: String
    var senderUserID: String
    var body: String
    var createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case threadID = "thread_id"
        case senderUserID = "sender_user_id"
        case body
        case createdAt = "created_at"
    }

    init(
        id: String = UUID().uuidString,
        threadID: String,
        senderUserID: String,
        body: String,
        createdAt: String? = nil
    ) {
        self.id = id
        self.threadID = threadID
        self.senderUserID = senderUserID
        self.body = body
        self.createdAt = createdAt
    }

    func message(for userID: String) -> DirectMessageMessage {
        DirectMessageMessage(
            id: id,
            sender: senderUserID == userID ? .me : .peer,
            body: body,
            sentAt: createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        )
    }
}

private struct SupabaseDMProfileRow: Codable, Equatable, Sendable {
    var userID: String
    var displayName: String
    var equippedThemeID: String?
    var profileTitle: String?

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case equippedThemeID = "equipped_theme_id"
        case profileTitle = "profile_title"
    }
}

private struct SupabaseDMFollowRow: Codable, Equatable, Sendable {
    var followerUserID: String
    var followedUserID: String

    private enum CodingKeys: String, CodingKey {
        case followerUserID = "follower_user_id"
        case followedUserID = "followed_user_id"
    }
}

private struct SupabaseDMBlockRow: Codable, Equatable, Sendable {
    var blockerUserID: String
    var blockedUserID: String

    private enum CodingKeys: String, CodingKey {
        case blockerUserID = "blocker_user_id"
        case blockedUserID = "blocked_user_id"
    }
}

public final class SupabaseDMRepository: DMRepository, @unchecked Sendable {
    private let configuration: SupabaseBackendConfiguration
    private let fallback: DMRepository
    private let httpClient: SupabaseHTTPClient
    private let diagnosticsStore: SupabaseDMSyncDiagnosticsStore
    private let authSessionProvider: @Sendable () -> SupabaseAuthSession?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSRecursiveLock()

    private var cachedThreads: [DirectMessageConversation] = []

    public init(
        configuration: SupabaseBackendConfiguration,
        fallback: DMRepository,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient(),
        diagnosticsStore: SupabaseDMSyncDiagnosticsStore,
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

    public func dmSyncDiagnostics() -> DMSyncDiagnostics {
        diagnosticsStore.load()
    }

    public func listThreads(for userID: String) -> [DirectMessageConversation] {
        let remote = withLock { cachedThreads }
        return remote.isEmpty ? fallback.listThreads(for: userID) : remote
    }

    public func thread(id: String, for userID: String) -> DirectMessageConversation? {
        listThreads(for: userID).first { $0.id == id || $0.participantUserID == id }
    }

    public func saveThread(_ thread: DirectMessageConversation, for userID: String) {
        fallback.saveThread(thread, for: userID)
    }

    public func deleteThread(id: String, for userID: String) {
        fallback.deleteThread(id: id, for: userID)
    }

    public func canStartThread(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool {
        fallback.canStartThread(from: profile, to: target)
    }

    public func refreshRemoteThreads(for profile: UserProfile) async throws -> DMSyncDiagnostics {
        let session = try usableSession()
        diagnosticsStore.record(status: .syncing, error: nil)
        do {
            let threads: [SupabaseDMThreadRow] = try await fetchRows(
                path: "/rest/v1/dm_threads",
                queryItems: [
                    URLQueryItem(name: "or", value: "(user_a_id.eq.\(session.userID),user_b_id.eq.\(session.userID))"),
                    URLQueryItem(name: "select", value: "id,user_a_id,user_b_id,updated_at"),
                    URLQueryItem(name: "order", value: "updated_at.desc"),
                    URLQueryItem(name: "limit", value: "40")
                ],
                session: session
            )
            let peerIDs = threads.map { $0.peerID(for: session.userID) }
            let profiles = try await fetchPeerProfiles(peerIDs: peerIDs, session: session)
            var conversations: [DirectMessageConversation] = []
            var messageCount = 0
            for thread in threads {
                let messages: [SupabaseDMMessageRow] = try await fetchRows(
                    path: "/rest/v1/dm_messages",
                    queryItems: [
                        URLQueryItem(name: "thread_id", value: "eq.\(thread.id)"),
                        URLQueryItem(name: "select", value: "id,thread_id,sender_user_id,body,created_at"),
                        URLQueryItem(name: "order", value: "created_at.asc"),
                        URLQueryItem(name: "limit", value: "80")
                    ],
                    session: session
                )
                let peerID = thread.peerID(for: session.userID)
                let peerProfile = profiles[peerID]
                let conversationMessages = messages.map { $0.message(for: session.userID) }
                messageCount += conversationMessages.count
                conversations.append(
                    DirectMessageConversation(
                        id: thread.id,
                        participantUserID: peerID,
                        participantDisplayName: peerProfile?.displayName ?? "プロフィールカード",
                        participantProfileTitle: peerProfile?.profileTitle,
                        participantDecorationID: peerProfile?.equippedThemeID ?? CardDecorationCatalog.classicId,
                        messages: conversationMessages,
                        updatedAt: thread.updatedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
                            ?? conversationMessages.last?.sentAt
                            ?? Date()
                    )
                )
            }
            withLock {
                cachedThreads = conversations.sorted { $0.updatedAt > $1.updatedAt }
            }
            diagnosticsStore.record(
                status: .synced,
                error: nil,
                threadCount: conversations.count,
                messageCount: messageCount
            )
            return diagnosticsStore.load()
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error))
            throw error
        }
    }

    public func sendMessage(to target: SocialUserProfileSummary, body: String, for profile: UserProfile) async throws -> DMSyncDiagnostics {
        let session = try usableSession()
        let peerID = try usableRemoteTargetID(target.id)
        let trimmed = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        guard !trimmed.isEmpty else {
            diagnosticsStore.record(status: .failed, error: "空のDMは送信できません", peerUserID: peerID)
            throw SupabaseDMRepositoryError.emptyMessage
        }
        guard peerID != session.userID else {
            diagnosticsStore.record(status: .failed, error: "自分自身にはDMできません", peerUserID: peerID)
            throw SupabaseDMRepositoryError.targetIsLocalOnly
        }

        diagnosticsStore.record(status: .syncing, error: nil, peerUserID: peerID)
        do {
            try await validateCanMessage(peerID: peerID, target: target, session: session)
            let thread = try await ensureThread(peerID: peerID, session: session)
            try await sendNoContent(
                path: "/rest/v1/dm_messages",
                queryItems: [],
                method: "POST",
                body: [
                    SupabaseDMMessageRow(
                        threadID: thread.id,
                        senderUserID: session.userID,
                        body: trimmed
                    )
                ],
                prefer: "return=minimal",
                session: session
            )
            try? await sendNoContent(
                path: "/rest/v1/dm_threads",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(thread.id)")],
                method: "PATCH",
                body: ["updated_at": ISO8601DateFormatter().string(from: Date())],
                prefer: "return=minimal",
                session: session
            )
            _ = try await refreshRemoteThreads(for: profile)
            diagnosticsStore.record(
                status: .synced,
                error: nil,
                threadCount: withLock { cachedThreads.count },
                messageCount: withLock { cachedThreads.reduce(0) { $0 + $1.messages.count } },
                threadID: thread.id,
                peerUserID: peerID
            )
            return diagnosticsStore.load()
        } catch {
            diagnosticsStore.record(status: .failed, error: readableError(error), peerUserID: peerID)
            throw error
        }
    }

    private func usableSession() throws -> SupabaseAuthSession {
        guard configuration.canUseSupabase else {
            diagnosticsStore.record(status: .localFallback, error: "Supabase が未設定です")
            throw SupabaseDMRepositoryError.unavailable(configuration.status)
        }
        guard let session = authSessionProvider(), session.hasUsableAccessToken() else {
            diagnosticsStore.record(status: .skippedSignedOut, error: "ローカル保存済み / Supabase認証待ち")
            throw SupabaseDMRepositoryError.supabaseAuthSessionMissing
        }
        return session
    }

    private func usableRemoteTargetID(_ targetUserID: String) throws -> String {
        let target = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: target) != nil else {
            diagnosticsStore.record(status: .localFallback, error: "ローカルプレビュー相手のためSupabase DM同期をスキップしました", peerUserID: target)
            throw SupabaseDMRepositoryError.targetIsLocalOnly
        }
        return target
    }

    private func validateCanMessage(peerID: String, target: SocialUserProfileSummary, session: SupabaseAuthSession) async throws {
        guard target.supportsMutualDM else {
            throw SupabaseDMRepositoryError.notMutualFollow
        }

        async let ownBlockRows: [SupabaseDMBlockRow] = fetchRows(
            path: "/rest/v1/blocks",
            queryItems: [
                URLQueryItem(name: "blocker_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "blocked_user_id", value: "eq.\(peerID)"),
                URLQueryItem(name: "select", value: "blocker_user_id,blocked_user_id"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        async let peerBlockRows: [SupabaseDMBlockRow] = fetchRows(
            path: "/rest/v1/blocks",
            queryItems: [
                URLQueryItem(name: "blocker_user_id", value: "eq.\(peerID)"),
                URLQueryItem(name: "blocked_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "blocker_user_id,blocked_user_id"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        async let followingRows: [SupabaseDMFollowRow] = fetchRows(
            path: "/rest/v1/follows",
            queryItems: [
                URLQueryItem(name: "follower_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "followed_user_id", value: "eq.\(peerID)"),
                URLQueryItem(name: "select", value: "follower_user_id,followed_user_id"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        async let followerRows: [SupabaseDMFollowRow] = fetchRows(
            path: "/rest/v1/follows",
            queryItems: [
                URLQueryItem(name: "follower_user_id", value: "eq.\(peerID)"),
                URLQueryItem(name: "followed_user_id", value: "eq.\(session.userID)"),
                URLQueryItem(name: "select", value: "follower_user_id,followed_user_id"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )

        let ownBlocks = try await ownBlockRows
        let peerBlocks = try await peerBlockRows
        let following = try await followingRows
        let followers = try await followerRows
        if !ownBlocks.isEmpty || !peerBlocks.isEmpty {
            throw SupabaseDMRepositoryError.blockedUser
        }
        guard !following.isEmpty, !followers.isEmpty else {
            throw SupabaseDMRepositoryError.notMutualFollow
        }
    }

    private func ensureThread(peerID: String, session: SupabaseAuthSession) async throws -> SupabaseDMThreadRow {
        let pair = Self.sortedPair(session.userID, peerID)
        let existing: [SupabaseDMThreadRow] = try await fetchRows(
            path: "/rest/v1/dm_threads",
            queryItems: [
                URLQueryItem(name: "user_a_id", value: "eq.\(pair.0)"),
                URLQueryItem(name: "user_b_id", value: "eq.\(pair.1)"),
                URLQueryItem(name: "select", value: "id,user_a_id,user_b_id,updated_at"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        if let thread = existing.first {
            return thread
        }

        let created: [SupabaseDMThreadRow] = try await sendReturningRows(
            path: "/rest/v1/dm_threads",
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_a_id,user_b_id")],
            method: "POST",
            body: [SupabaseDMThreadRow(userAID: pair.0, userBID: pair.1)],
            prefer: "resolution=ignore-duplicates,return=representation",
            session: session
        )
        if let thread = created.first {
            return thread
        }

        let retried: [SupabaseDMThreadRow] = try await fetchRows(
            path: "/rest/v1/dm_threads",
            queryItems: [
                URLQueryItem(name: "user_a_id", value: "eq.\(pair.0)"),
                URLQueryItem(name: "user_b_id", value: "eq.\(pair.1)"),
                URLQueryItem(name: "select", value: "id,user_a_id,user_b_id,updated_at"),
                URLQueryItem(name: "limit", value: "1")
            ],
            session: session
        )
        guard let thread = retried.first else {
            throw SupabaseDMRepositoryError.emptyResponse
        }
        return thread
    }

    private func fetchPeerProfiles(peerIDs: [String], session: SupabaseAuthSession) async throws -> [String: SupabaseDMProfileRow] {
        let uniqueIDs = Array(Set(peerIDs)).sorted()
        guard !uniqueIDs.isEmpty else { return [:] }
        let rows: [SupabaseDMProfileRow] = try await fetchRows(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "user_id", value: "in.(\(uniqueIDs.joined(separator: ",")))"),
                URLQueryItem(name: "select", value: "user_id,display_name,equipped_theme_id,profile_title")
            ],
            session: session
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.userID, $0) })
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
            throw SupabaseDMRepositoryError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
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
            throw SupabaseDMRepositoryError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    private func sendReturningRows<Body: Encodable, Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        body: Body?,
        prefer: String?,
        session: SupabaseAuthSession
    ) async throws -> [Response] {
        let request = try makeRequest(
            path: path,
            queryItems: queryItems,
            method: method,
            body: body,
            prefer: prefer,
            session: session
        )
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseDMRepositoryError.invalidResponse(response.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else { return [] }
        return try decoder.decode([Response].self, from: data)
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
            throw SupabaseDMRepositoryError.unavailable(configuration.status)
        }
        components.path = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw SupabaseDMRepositoryError.unavailable(.invalidConfiguration)
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

    private func readableError(_ error: Error) -> String {
        if case let SupabaseDMRepositoryError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 401, 403:
                return "HTTP \(statusCode): DM同期がRLSで拒否されました。Supabase Auth session、相互フォロー、ブロック状態、auth.uid() を確認してください。\(String(message.prefix(140)))"
            case 404:
                return "HTTP 404: dm_threads/dm_messages テーブルまたはpolicyを確認してください。\(String(message.prefix(140)))"
            default:
                return "HTTP \(statusCode): DM同期に失敗しました。\(String(message.prefix(140)))"
            }
        }
        if case SupabaseDMRepositoryError.supabaseAuthSessionMissing = error {
            return "ローカル保存済み / Supabase認証待ち"
        }
        if case SupabaseDMRepositoryError.targetIsLocalOnly = error {
            return "ローカルプレビュー相手のためSupabase DM同期をスキップしました"
        }
        if case SupabaseDMRepositoryError.notMutualFollow = error {
            return "DMは相互フォローの相手とのみ同期できます"
        }
        if case SupabaseDMRepositoryError.blockedUser = error {
            return "ブロック中の相手にはDMできません"
        }
        if case SupabaseDMRepositoryError.emptyMessage = error {
            return "空のDMは送信できません"
        }
        if case let SupabaseDMRepositoryError.unavailable(status) = error {
            return "Supabase が利用できません: \(status.label)"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func sortedPair(_ lhs: String, _ rhs: String) -> (String, String) {
        lhs < rhs ? (lhs, rhs) : (rhs, lhs)
    }
}
