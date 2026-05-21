import Foundation
import Domain

public struct SupabaseProfilePayload: Codable, Equatable, Sendable {
    public var userID: String
    public var displayName: String
    public var bio: String?
    public var avatarSymbol: String?
    public var interestTags: [String]
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case bio
        case avatarSymbol = "avatar_symbol"
        case interestTags = "interest_tags"
        case updatedAt = "updated_at"
    }

    public init(
        userID: String,
        displayName: String,
        bio: String?,
        avatarSymbol: String?,
        interestTags: [String],
        updatedAt: Date
    ) {
        self.userID = userID
        self.displayName = displayName
        self.bio = bio
        self.avatarSymbol = avatarSymbol
        self.interestTags = interestTags
        self.updatedAt = updatedAt
    }

    public static func make(
        from profile: UserProfile,
        owner: ProfileOwnerIdentity,
        updatedAt: Date = Date()
    ) -> SupabaseProfilePayload {
        var copy = profile
        copy.normalize()
        return SupabaseProfilePayload(
            userID: owner.userID,
            displayName: copy.displayName,
            bio: copy.profileBio,
            avatarSymbol: copy.avatarSymbol,
            interestTags: copy.interestTags,
            updatedAt: updatedAt
        )
    }
}

public struct SupabaseProfileUserRow: Codable, Equatable, Sendable {
    public var id: String
    public var authProvider: String
    public var providerUserID: String
    public var email: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case authProvider = "auth_provider"
        case providerUserID = "provider_user_id"
        case email
    }
}

public struct SupabaseProfileRow: Codable, Equatable, Sendable {
    public var userID: String
    public var displayName: String
    public var bio: String?
    public var avatarSymbol: String?
    public var interestTags: [String]
    public var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case bio
        case avatarSymbol = "avatar_symbol"
        case interestTags = "interest_tags"
        case updatedAt = "updated_at"
    }

    public func merged(into local: UserProfile) -> UserProfile {
        var profile = local
        profile.displayName = displayName
        profile.profileBio = bio
        profile.avatarSymbol = avatarSymbol
        profile.interestTags = interestTags
        profile.normalize()
        return profile
    }
}

public enum SupabaseProfileError: Error, Equatable, Sendable {
    case unavailable(SupabaseBackendStatus)
    case signedOut
    case supabaseAuthSessionMissing
    case invalidOwner
    case invalidResponse(Int, String)
    case emptyResponse
}

public protocol SupabaseProfileClient: Sendable {
    func upsertUser(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileUserRow
    func fetchProfile(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileRow?
    func upsertProfile(_ payload: SupabaseProfilePayload) async throws -> SupabaseProfileRow
}

public struct SupabaseProfileRESTClient: SupabaseProfileClient {
    private let configuration: SupabaseBackendConfiguration
    private let httpClient: SupabaseHTTPClient
    private let accessTokenProvider: @Sendable () -> String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: SupabaseBackendConfiguration,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient(),
        accessTokenProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.accessTokenProvider = accessTokenProvider
        self.encoder = SupabaseProfileRESTClient.makeJSONEncoder()
        self.decoder = SupabaseProfileRESTClient.makeJSONDecoder()
    }

    public func upsertUser(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileUserRow {
        guard configuration.canUseSupabase else {
            throw SupabaseProfileError.unavailable(configuration.status)
        }
        guard owner.isUsable else {
            throw SupabaseProfileError.invalidOwner
        }

        let body = [
            SupabaseProfileUserRow(
                id: owner.userID,
                authProvider: owner.provider,
                providerUserID: owner.providerUserID,
                email: owner.email
            )
        ]
        let request = try makeRequest(
            path: "/rest/v1/users",
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "auth_provider,provider_user_id"),
                URLQueryItem(name: "select", value: "id,auth_provider,provider_user_id,email")
            ],
            method: "POST",
            prefer: "resolution=merge-duplicates,return=representation",
            body: body
        )
        let rows: [SupabaseProfileUserRow] = try await send(request)
        guard let row = rows.first else { throw SupabaseProfileError.emptyResponse }
        return row
    }

    public func fetchProfile(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileRow? {
        guard configuration.canUseSupabase else {
            throw SupabaseProfileError.unavailable(configuration.status)
        }
        guard owner.isUsable else {
            throw SupabaseProfileError.invalidOwner
        }

        let request = try makeRequest(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(owner.userID)"),
                URLQueryItem(name: "select", value: "user_id,display_name,bio,avatar_symbol,interest_tags,updated_at"),
                URLQueryItem(name: "limit", value: "1")
            ],
            method: "GET",
            prefer: nil,
            body: Optional<String>.none
        )
        let rows: [SupabaseProfileRow] = try await send(request)
        return rows.first
    }

    public func upsertProfile(_ payload: SupabaseProfilePayload) async throws -> SupabaseProfileRow {
        guard configuration.canUseSupabase else {
            throw SupabaseProfileError.unavailable(configuration.status)
        }

        let request = try makeRequest(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "user_id"),
                URLQueryItem(name: "select", value: "user_id,display_name,bio,avatar_symbol,interest_tags,updated_at")
            ],
            method: "POST",
            prefer: "resolution=merge-duplicates,return=representation",
            body: [payload]
        )
        let rows: [SupabaseProfileRow] = try await send(request)
        guard let row = rows.first else { throw SupabaseProfileError.emptyResponse }
        return row
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        queryItems: [URLQueryItem],
        method: String,
        prefer: String?,
        body: Body?
    ) throws -> URLRequest {
        guard let projectURL = configuration.projectURL,
              let anonKey = configuration.anonKey,
              var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseProfileError.unavailable(configuration.status)
        }
        components.path = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw SupabaseProfileError.unavailable(.invalidConfiguration)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessTokenProvider() ?? anonKey)", forHTTPHeaderField: "Authorization")
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

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw SupabaseProfileError.invalidResponse(response.statusCode, message)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public protocol SupabaseHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionSupabaseHTTPClient: SupabaseHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseProfileError.invalidResponse(-1, "HTTPレスポンスを取得できませんでした")
        }
        return (data, httpResponse)
    }
}

public final class SupabaseProfileSyncDiagnosticsStore: @unchecked Sendable {
    public static let storeKey = "MyDailyPhrase.backend.profileSync.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func load() -> ProfileSyncDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.storeKey),
                  let diagnostics = try? decoder.decode(ProfileSyncDiagnostics.self, from: data) else {
                return .localFallback
            }
            return diagnostics
        }
    }

    public func save(_ diagnostics: ProfileSyncDiagnostics) {
        withLock {
            guard let data = try? encoder.encode(diagnostics) else { return }
            defaults.set(data, forKey: Self.storeKey)
        }
    }

    public func record(
        status: ProfileSyncStatus,
        error: String? = nil,
        userID: String? = nil,
        date: Date = Date()
    ) {
        save(
            ProfileSyncDiagnostics(
                status: status,
                lastErrorMessage: error,
                lastSyncAt: status == .synced ? date : load().lastSyncAt,
                lastAttemptAt: date,
                lastSyncedUserID: userID ?? load().lastSyncedUserID
            )
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

public final class SupabaseProfileRepository: ProfileRepository, @unchecked Sendable {
    private let configuration: SupabaseBackendConfiguration
    private let fallback: ProfileRepository
    private let client: SupabaseProfileClient
    private let diagnosticsStore: SupabaseProfileSyncDiagnosticsStore
    private let authSessionProvider: @Sendable () -> SupabaseAuthSession?

    public init(
        configuration: SupabaseBackendConfiguration,
        fallback: ProfileRepository,
        client: SupabaseProfileClient? = nil,
        diagnosticsStore: SupabaseProfileSyncDiagnosticsStore,
        authSessionProvider: @escaping @Sendable () -> SupabaseAuthSession? = { nil }
    ) {
        self.configuration = configuration
        self.fallback = fallback
        self.client = client ?? SupabaseProfileRESTClient(
            configuration: configuration,
            accessTokenProvider: { authSessionProvider()?.accessToken }
        )
        self.diagnosticsStore = diagnosticsStore
        self.authSessionProvider = authSessionProvider
    }

    public var mode: SocialBackendMode {
        configuration.canUseSupabase ? .supabase : .localFallback
    }

    public var isBackendEnabled: Bool {
        configuration.canUseSupabase
    }

    public func profileSyncDiagnostics() -> ProfileSyncDiagnostics {
        diagnosticsStore.load()
    }

    public func getMyProfile() -> UserProfile? {
        fallback.getMyProfile()
    }

    public func saveMyProfile(_ profile: UserProfile) {
        fallback.saveMyProfile(profile)
        scheduleProfileUpsertIfPossible(profile)
    }

    @discardableResult
    public func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        let profile = fallback.mutateMyProfile(mutate, makeIfMissing: makeIfMissing)
        scheduleProfileUpsertIfPossible(profile)
        return profile
    }

    public func fetchCurrentUserProfile(owner: ProfileOwnerIdentity) async throws -> UserProfile? {
        guard configuration.canUseSupabase else {
            diagnosticsStore.record(status: .localFallback)
            return fallback.getMyProfile()
        }
        guard owner.isUsable else {
            diagnosticsStore.record(status: .skippedSignedOut)
            throw SupabaseProfileError.signedOut
        }
        guard let remoteOwner = authenticatedRemoteOwner(from: owner) else {
            diagnosticsStore.record(
                status: .skippedSupabaseAuthMissing,
                error: "ローカル保存済み / Supabase認証待ち"
            )
            return fallback.getMyProfile()
        }

        diagnosticsStore.record(status: .syncing, userID: remoteOwner.userID)
        do {
            _ = try await client.upsertUser(owner: remoteOwner)
            guard let remote = try await client.fetchProfile(owner: remoteOwner) else {
                diagnosticsStore.record(status: .idle, userID: remoteOwner.userID)
                return fallback.getMyProfile()
            }
            let merged = remote.merged(into: fallback.getMyProfile() ?? UserProfile(userId: owner.userID, displayName: remote.displayName))
            fallback.saveMyProfile(merged)
            diagnosticsStore.record(status: .synced, userID: remoteOwner.userID)
            return merged
        } catch {
            diagnosticsStore.record(status: .failed, error: safeErrorMessage(error), userID: remoteOwner.userID)
            throw error
        }
    }

    public func upsertCurrentUserProfile(_ profile: UserProfile, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        guard configuration.canUseSupabase else {
            fallback.saveMyProfile(profile)
            diagnosticsStore.record(status: .localFallback)
            return profile
        }
        guard owner.isUsable else {
            fallback.saveMyProfile(profile)
            diagnosticsStore.record(status: .skippedSignedOut)
            throw SupabaseProfileError.signedOut
        }
        guard let remoteOwner = authenticatedRemoteOwner(from: owner) else {
            fallback.saveMyProfile(profile)
            diagnosticsStore.record(
                status: .skippedSupabaseAuthMissing,
                error: "ローカル保存済み / Supabase認証待ち"
            )
            throw SupabaseProfileError.supabaseAuthSessionMissing
        }

        diagnosticsStore.record(status: .syncing, userID: remoteOwner.userID)
        do {
            _ = try await client.upsertUser(owner: remoteOwner)
            let payload = SupabaseProfilePayload.make(from: profile, owner: remoteOwner)
            let row = try await client.upsertProfile(payload)
            let merged = row.merged(into: profile)
            fallback.saveMyProfile(merged)
            diagnosticsStore.record(status: .synced, userID: remoteOwner.userID)
            return merged
        } catch {
            fallback.saveMyProfile(profile)
            diagnosticsStore.record(status: .failed, error: safeErrorMessage(error), userID: remoteOwner.userID)
            throw error
        }
    }

    public func updateDisplayName(_ displayName: String, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        let profile = fallback.mutateMyProfile(
            { $0.displayName = displayName },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: displayName) }
        )
        return try await upsertCurrentUserProfile(profile, owner: owner)
    }

    public func updateBio(_ bio: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        let profile = fallback.mutateMyProfile(
            { $0.profileBio = bio },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", profileBio: bio) }
        )
        return try await upsertCurrentUserProfile(profile, owner: owner)
    }

    public func updateAvatarSymbol(_ avatarSymbol: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        let profile = fallback.mutateMyProfile(
            { $0.avatarSymbol = avatarSymbol },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", avatarSymbol: avatarSymbol) }
        )
        return try await upsertCurrentUserProfile(profile, owner: owner)
    }

    public func updateInterestTags(_ interestTags: [String], owner: ProfileOwnerIdentity) async throws -> UserProfile {
        let profile = fallback.mutateMyProfile(
            { $0.interestTags = interestTags },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", interestTags: interestTags) }
        )
        return try await upsertCurrentUserProfile(profile, owner: owner)
    }

    private func scheduleProfileUpsertIfPossible(_ profile: UserProfile) {
        guard configuration.canUseSupabase else {
            diagnosticsStore.record(status: .localFallback)
            return
        }
        guard let owner = ProfileOwnerIdentity(profile: profile) else {
            diagnosticsStore.record(status: .skippedSignedOut)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.upsertCurrentUserProfile(profile, owner: owner)
            } catch {
                // Diagnostics are recorded inside upsert; local profile has already been saved.
            }
        }
    }

    private func safeErrorMessage(_ error: Error) -> String {
        switch error {
        case let SupabaseProfileError.invalidResponse(statusCode, message):
            return "HTTP \(statusCode): \(String(message.prefix(180)))"
        case SupabaseProfileError.supabaseAuthSessionMissing:
            return "ローカル保存済み / Supabase認証待ち"
        default:
            return String(error.localizedDescription.prefix(180))
        }
    }

    private func authenticatedRemoteOwner(from owner: ProfileOwnerIdentity) -> ProfileOwnerIdentity? {
        guard let session = authSessionProvider(),
              session.hasUsableAccessToken() else {
            return nil
        }
        return ProfileOwnerIdentity(
            userID: session.userID,
            provider: owner.provider,
            providerUserID: owner.providerUserID,
            email: owner.email
        )
    }
}
