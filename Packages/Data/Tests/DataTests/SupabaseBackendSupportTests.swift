import Foundation
import Testing
import Domain
@testable import Data

@Suite("Supabase backend support")
struct SupabaseBackendSupportTests {
    @Test("empty Supabase config is disabled and uses local fallback")
    func emptyConfigIsDisabled() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: false,
            projectURLString: nil,
            anonKey: nil
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .disabled)
        #expect(config.canUseSupabase == false)
        #expect(snapshot.activeMode == .localFallback)
        #expect(snapshot.backendModeLabel == "localFallback")
        #expect(snapshot.publicFeedEnabled == false)
        #expect(snapshot.commentsEnabled == false)
        #expect(snapshot.rankingEnabled == false)
        #expect(snapshot.dmPolicy == "mutual_follow_only")
    }

    @Test("enabled Supabase without URL or key is safe missing configuration")
    func missingConfigIsSafe() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "",
            anonKey: " "
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .missingConfiguration)
        #expect(snapshot.activeMode == .localFallback)
        #expect(snapshot.anonKeyConfigured == false)
    }

    @Test("invalid Supabase URL is safe and keeps local fallback")
    func invalidConfigIsSafe() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "not-a-supabase-url",
            anonKey: "public-anon-key"
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .invalidConfiguration)
        #expect(config.canUseSupabase == false)
        #expect(snapshot.activeMode == .localFallback)
    }

    @Test("configured Supabase reports supabase active mode")
    func configuredSupabaseReportsActiveMode() {
        let publishableKey = "sb_publishable_lq54eBvrXa7v6ouvvIsgKQ_Z6xwnTUq"
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: publishableKey
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .configured)
        #expect(config.canUseAppleAuthBridge == false)
        #expect(snapshot.activeMode == .supabase)
        #expect(snapshot.backendModeLabel == "supabaseConfigured")
        #expect(snapshot.projectURLHost == "example.supabase.co")
        #expect(snapshot.anonKeyConfigured)
        #expect(snapshot.keyType == "publishable")
        #expect(snapshot.keySafePrefix == "sb_publishable")
        #expect(snapshot.secretsInRepository == false)
        #expect(snapshot.reportText.contains(publishableKey) == false)
    }

    @Test("configured Supabase Auth bridge reports safe diagnostics")
    func configuredSupabaseAuthBridgeReportsSafeDiagnostics() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "sb_publishable_test",
            authEnabledConfigured: true,
            appleAuthEnabledConfigured: true
        )
        let diagnostics = SupabaseAuthDiagnostics(
            status: .signedIn,
            supabaseUserID: "22222222-2222-4222-8222-222222222222",
            accessTokenPresent: true,
            refreshTokenPresent: true,
            tokenExpiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            lastErrorMessage: nil,
            lastAuthAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config, authDiagnostics: diagnostics)

        #expect(config.canUseAppleAuthBridge)
        #expect(snapshot.supabaseAuthStatus == .signedIn)
        #expect(snapshot.supabaseAccessTokenPresent)
        #expect(snapshot.supabaseRefreshTokenPresent)
        #expect(snapshot.reportText.contains("access-token") == false)
        #expect(snapshot.reportText.contains("refresh-token") == false)
    }

    @Test("Apple identity token can create Supabase Auth session without exposing tokens")
    func appleIdentityTokenCreatesSupabaseSession() async throws {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "sb_publishable_test",
            authEnabledConfigured: true,
            appleAuthEnabledConfigured: true
        )
        let body = """
        {
          "access_token": "access-token-secret",
          "refresh_token": "refresh-token-secret",
          "expires_in": 3600,
          "user": { "id": "22222222-2222-4222-8222-222222222222" }
        }
        """
        let httpClient = MockSupabaseHTTPClient(statusCode: 200, body: body)
        let client = SupabaseAuthRESTClient(configuration: config, httpClient: httpClient)

        let session = try await client.signInWithAppleIdentityToken(idToken: "apple-id-token", nonce: "raw-nonce")

        #expect(session.userID == "22222222-2222-4222-8222-222222222222")
        #expect(session.hasAccessToken)
        #expect(httpClient.lastRequest?.url?.absoluteString.contains("/auth/v1/token?grant_type=id_token") == true)
        #expect(httpClient.lastRequestBodyString?.contains("\"provider\":\"apple\"") == true)
        #expect(httpClient.lastRequestBodyString?.contains("\"id_token\":\"apple-id-token\"") == true)
        #expect(httpClient.lastRequestBodyString?.contains("\"nonce\":\"raw-nonce\"") == true)
    }

    @Test("profile table mapping matches schema")
    func profileTableMappingMatchesSchema() {
        #expect(SupabaseBackendConfiguration.profilesTableName == "profiles")
    }

    @Test("connection test reaches profiles table without exposing key")
    func connectionTestUsesProfilesTable() async {
        let key = "sb_publishable_lq54eBvrXa7v6ouvvIsgKQ_Z6xwnTUq"
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: key
        )
        let httpClient = MockSupabaseHTTPClient(statusCode: 200, body: "[]")
        let tester = SupabaseBackendConnectionTester(configuration: config, httpClient: httpClient)

        let result = await tester.testProfilesTableRead()

        #expect(result.diagnostics.status == .reachable)
        #expect(result.tableName == "profiles")
        #expect(result.keyType == "publishable")
        #expect(httpClient.lastRequest?.url?.absoluteString.contains("/rest/v1/profiles") == true)
        #expect(httpClient.lastRequest?.value(forHTTPHeaderField: "apikey") == key)
        #expect(BackendDiagnosticsSnapshot(configuration: config, connectionDiagnostics: result.diagnostics).reportText.contains(key) == false)
    }

    @Test("connection test gives RLS guidance for permission errors")
    func connectionTestRLSGuidance() async {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "sb_publishable_test"
        )
        let httpClient = MockSupabaseHTTPClient(statusCode: 403, body: "{\"message\":\"permission denied\"}")
        let tester = SupabaseBackendConnectionTester(configuration: config, httpClient: httpClient)

        let result = await tester.testProfilesTableRead()

        #expect(result.diagnostics.status == .failed)
        #expect(result.diagnostics.lastErrorMessage?.contains("RLS") == true)
        #expect(result.diagnostics.lastErrorMessage?.contains("profiles") == true)
    }

    @Test("profile payload maps app fields to Supabase profile columns")
    func profilePayloadMapsFields() {
        let profile = UserProfile(
            userId: "11111111-1111-4111-8111-111111111111",
            displayName: "  ねこ 勇者  ",
            profileBio: "RPGが好き",
            avatarSymbol: "🐱",
            interestTags: ["RPG", "猫"]
        )
        let owner = ProfileOwnerIdentity(
            userID: profile.userId,
            provider: "apple",
            providerUserID: "apple-subject"
        )
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let payload = SupabaseProfilePayload.make(from: profile, owner: owner, updatedAt: date)

        #expect(payload.userID == "11111111-1111-4111-8111-111111111111")
        #expect(payload.displayName == "ねこ 勇者")
        #expect(payload.bio == "RPGが好き")
        #expect(payload.avatarSymbol == "🐱")
        #expect(payload.interestTags == ["RPG", "猫"])
        #expect(payload.updatedAt == date)
    }

    @Test("signed out profile does not attempt Supabase profile write")
    func signedOutProfileDoesNotWriteToBackend() async {
        let repository = makeSupabaseProfileRepository()
        let profile = UserProfile(userId: "11111111-1111-4111-8111-111111111111", displayName: "Me")

        repository.repository.saveMyProfile(profile)

        #expect(repository.client.upsertUserCallCount == 0)
        #expect(repository.client.upsertProfileCallCount == 0)
        #expect(repository.repository.profileSyncDiagnostics().status == .skippedSignedOut)
    }

    @Test("backend failure preserves local profile and records safe error")
    func backendFailurePreservesLocalProfile() async {
        let repository = makeSupabaseProfileRepository(
            authSession: SupabaseAuthSession(
                userID: "22222222-2222-4222-8222-222222222222",
                accessToken: "access-token-secret",
                refreshToken: nil,
                expiresAt: Date().addingTimeInterval(3600)
            )
        )
        repository.client.shouldFailProfileUpsert = true
        let profile = UserProfile(
            userId: "11111111-1111-4111-8111-111111111111",
            displayName: "同期テスト",
            profileBio: "ローカルは残る",
            linkedAuthProvider: "apple",
            linkedAuthUserId: "apple-subject"
        )
        let owner = ProfileOwnerIdentity(profile: profile)!

        do {
            _ = try await repository.repository.upsertCurrentUserProfile(profile, owner: owner)
            Issue.record("upsert should throw")
        } catch {
            #expect(repository.fallback.getMyProfile()?.displayName == "同期テスト")
            #expect(repository.repository.profileSyncDiagnostics().status == .failed)
            #expect(repository.repository.profileSyncDiagnostics().lastErrorMessage?.contains("HTTP 500") == true)
        }
    }

    @Test("Supabase reachable but no Supabase Auth session does not attempt remote profile write")
    func noSupabaseAuthSessionSkipsRemoteWrite() async {
        let repository = makeSupabaseProfileRepository()
        let profile = UserProfile(
            userId: "11111111-1111-4111-8111-111111111111",
            displayName: "同期テスト",
            linkedAuthProvider: "apple",
            linkedAuthUserId: "apple-subject"
        )
        let owner = ProfileOwnerIdentity(profile: profile)!

        do {
            _ = try await repository.repository.upsertCurrentUserProfile(profile, owner: owner)
            Issue.record("upsert should wait for Supabase Auth")
        } catch {
            #expect(error as? SupabaseProfileError == .supabaseAuthSessionMissing)
            #expect(repository.client.upsertUserCallCount == 0)
            #expect(repository.client.upsertProfileCallCount == 0)
            #expect(repository.fallback.getMyProfile()?.displayName == "同期テスト")
            #expect(repository.repository.profileSyncDiagnostics().status == .skippedSupabaseAuthMissing)
        }
    }

    @Test("Supabase authenticated user id is used for users and profiles")
    func supabaseAuthenticatedUserIDIsUsedForProfileRows() async throws {
        let repository = makeSupabaseProfileRepository(
            authSession: SupabaseAuthSession(
                userID: "22222222-2222-4222-8222-222222222222",
                accessToken: "access-token-secret",
                refreshToken: nil,
                expiresAt: Date().addingTimeInterval(3600)
            )
        )
        let profile = UserProfile(
            userId: "11111111-1111-4111-8111-111111111111",
            displayName: "同期テスト",
            linkedAuthProvider: "apple",
            linkedAuthUserId: "apple-subject"
        )
        let owner = ProfileOwnerIdentity(profile: profile)!

        _ = try await repository.repository.upsertCurrentUserProfile(profile, owner: owner)

        #expect(repository.client.lastUpsertUserOwner?.userID == "22222222-2222-4222-8222-222222222222")
        #expect(repository.client.lastUpsertProfilePayload?.userID == "22222222-2222-4222-8222-222222222222")
        #expect(repository.client.lastUpsertUserOwner?.providerUserID == "apple-subject")
    }

    @Test("backend diagnostics never exposes anon key value")
    func diagnosticsDoesNotExposeAnonKey() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "very-secret-anon-key"
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(snapshot.reportText.contains("anonKeyConfigured: true"))
        #expect(snapshot.reportText.contains("very-secret-anon-key") == false)
    }

    @Test("local social repository excludes blocked recommendations and gates DM")
    func localSocialRepositorySafety() {
        let minato = SocialUserProfileSummary(
            id: "local.profile.minato",
            displayName: "ミナト",
            equippedThemeId: "classic",
            joinedCommunityCount: 1,
            supportsMutualDM: true
        )
        let sora = SocialUserProfileSummary(
            id: "local.profile.sora",
            displayName: "ソラ",
            equippedThemeId: "classic",
            joinedCommunityCount: 1,
            supportsMutualDM: true
        )
        let repository = LocalSocialConnectionRepository {
            [minato, sora]
        }
        var profile = UserProfile(
            userId: "me",
            displayName: "Me",
            followingUserIDs: ["local.profile.minato"],
            blockedUserIDs: ["local.profile.sora"]
        )
        profile.normalize()

        #expect(repository.listRecommendedProfiles(for: profile).isEmpty)
        #expect(repository.listFollowingProfiles(for: profile).map(\.id) == ["local.profile.minato"])
        #expect(repository.canStartDirectMessage(from: profile, to: minato))
        #expect(repository.canStartDirectMessage(from: profile, to: sora) == false)
    }

    private func makeSupabaseProfileRepository() -> (
        repository: SupabaseProfileRepository,
        fallback: AppGroupUserProfileRepository,
        client: MockSupabaseProfileClient
    ) {
        makeSupabaseProfileRepository(authSession: nil)
    }

    private func makeSupabaseProfileRepository(authSession: SupabaseAuthSession?) -> (
        repository: SupabaseProfileRepository,
        fallback: AppGroupUserProfileRepository,
        client: MockSupabaseProfileClient
    ) {
        let suiteName = "group.MyDailyPhrase.supabase.profile.tests.\(UUID().uuidString)"
        let fallback = AppGroupUserProfileRepository(appGroupID: suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "public-anon-key"
        )
        let client = MockSupabaseProfileClient()
        let repository = SupabaseProfileRepository(
            configuration: config,
            fallback: fallback,
            client: client,
            diagnosticsStore: SupabaseProfileSyncDiagnosticsStore(defaults: defaults),
            authSessionProvider: { authSession }
        )
        return (repository, fallback, client)
    }
}

private final class MockSupabaseProfileClient: SupabaseProfileClient, @unchecked Sendable {
    var upsertUserCallCount = 0
    var upsertProfileCallCount = 0
    var shouldFailProfileUpsert = false
    private(set) var lastUpsertUserOwner: ProfileOwnerIdentity?
    private(set) var lastUpsertProfilePayload: SupabaseProfilePayload?

    func upsertUser(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileUserRow {
        upsertUserCallCount += 1
        lastUpsertUserOwner = owner
        return SupabaseProfileUserRow(
            id: owner.userID,
            authProvider: owner.provider,
            providerUserID: owner.providerUserID,
            email: owner.email
        )
    }

    func fetchProfile(owner: ProfileOwnerIdentity) async throws -> SupabaseProfileRow? {
        SupabaseProfileRow(
            userID: owner.userID,
            displayName: "Remote",
            bio: "Remote bio",
            avatarSymbol: "☁️",
            interestTags: ["remote"],
            updatedAt: Date()
        )
    }

    func upsertProfile(_ payload: SupabaseProfilePayload) async throws -> SupabaseProfileRow {
        upsertProfileCallCount += 1
        lastUpsertProfilePayload = payload
        if shouldFailProfileUpsert {
            throw SupabaseProfileError.invalidResponse(500, "server failed without secrets")
        }
        return SupabaseProfileRow(
            userID: payload.userID,
            displayName: payload.displayName,
            bio: payload.bio,
            avatarSymbol: payload.avatarSymbol,
            interestTags: payload.interestTags,
            updatedAt: payload.updatedAt
        )
    }
}

private final class MockSupabaseHTTPClient: SupabaseHTTPClient, @unchecked Sendable {
    let statusCode: Int
    let body: String
    private(set) var lastRequest: URLRequest?
    private(set) var lastRequestBodyString: String?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        lastRequestBodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.supabase.co")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}
