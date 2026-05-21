import Foundation

public struct SupabaseAuthSession: Codable, Equatable, Sendable {
    public var userID: String
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var provider: String
    public var providerUserID: String?

    public init(
        userID: String,
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        provider: String = "apple",
        providerUserID: String? = nil
    ) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRefresh = refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.refreshToken = trimmedRefresh?.isEmpty == false ? trimmedRefresh : nil
        self.expiresAt = expiresAt
        self.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedProviderUserID = providerUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerUserID = trimmedProviderUserID?.isEmpty == false ? trimmedProviderUserID : nil
    }

    public var hasAccessToken: Bool {
        !accessToken.isEmpty
    }

    public func hasUsableAccessToken(now: Date = Date()) -> Bool {
        guard hasAccessToken else { return false }
        guard let expiresAt else { return true }
        return expiresAt.timeIntervalSince(now) > 30
    }
}

public enum SupabaseAuthBridgeError: Error, Equatable, Sendable {
    case disabled
    case missingConfiguration
    case missingAppleIdentityToken
    case invalidAppleIdentityToken
    case invalidResponse(Int, String)
    case emptyResponse
}

public protocol SupabaseAuthClient: Sendable {
    func signInWithAppleIdentityToken(
        idToken: String,
        nonce: String?
    ) async throws -> SupabaseAuthSession
}

public struct SupabaseAuthRESTClient: SupabaseAuthClient {
    private struct RequestBody: Encodable {
        var provider: String
        var idToken: String
        var nonce: String?

        private enum CodingKeys: String, CodingKey {
            case provider
            case idToken = "id_token"
            case nonce
        }
    }

    private struct ResponseBody: Decodable {
        struct User: Decodable {
            var id: String
        }

        var accessToken: String
        var refreshToken: String?
        var expiresIn: Int?
        var expiresAt: Int?
        var user: User

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case expiresAt = "expires_at"
            case user
        }
    }

    private let configuration: SupabaseBackendConfiguration
    private let httpClient: SupabaseHTTPClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        configuration: SupabaseBackendConfiguration,
        httpClient: SupabaseHTTPClient = URLSessionSupabaseHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    public func signInWithAppleIdentityToken(
        idToken: String,
        nonce: String?
    ) async throws -> SupabaseAuthSession {
        guard configuration.canUseAppleAuthBridge else {
            throw configuration.canUseSupabase ? SupabaseAuthBridgeError.disabled : SupabaseAuthBridgeError.missingConfiguration
        }

        let trimmedIDToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIDToken.isEmpty else {
            throw SupabaseAuthBridgeError.missingAppleIdentityToken
        }

        guard let projectURL = configuration.projectURL,
              let anonKey = configuration.anonKey,
              var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthBridgeError.missingConfiguration
        }

        components.path = "/auth/v1/token"
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let url = components.url else {
            throw SupabaseAuthBridgeError.missingConfiguration
        }

        let trimmedNonce = nonce?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = RequestBody(
            provider: "apple",
            idToken: trimmedIDToken,
            nonce: trimmedNonce?.isEmpty == false ? trimmedNonce : nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw SupabaseAuthBridgeError.invalidResponse(response.statusCode, message)
        }

        let decoded = try decoder.decode(ResponseBody.self, from: data)
        let expiresAt: Date? = {
            if let unix = decoded.expiresAt {
                return Date(timeIntervalSince1970: TimeInterval(unix))
            }
            if let seconds = decoded.expiresIn {
                return Date().addingTimeInterval(TimeInterval(seconds))
            }
            return nil
        }()

        let session = SupabaseAuthSession(
            userID: decoded.user.id,
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: expiresAt,
            provider: "apple",
            providerUserID: nil
        )
        guard session.hasAccessToken, !session.userID.isEmpty else {
            throw SupabaseAuthBridgeError.emptyResponse
        }
        return session
    }
}

public final class SupabaseAuthSessionStore: @unchecked Sendable {
    public static let sessionKey = "MyDailyPhrase.backend.supabaseAuth.session.v1"
    public static let diagnosticsKey = "MyDailyPhrase.backend.supabaseAuth.diagnostics.v1"

    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func loadSession() -> SupabaseAuthSession? {
        withLock {
            guard let data = defaults.data(forKey: Self.sessionKey),
                  let session = try? decoder.decode(SupabaseAuthSession.self, from: data),
                  session.hasAccessToken else {
                return nil
            }
            return session
        }
    }

    public func saveSession(_ session: SupabaseAuthSession) {
        withLock {
            guard let data = try? encoder.encode(session) else { return }
            defaults.set(data, forKey: Self.sessionKey)
            saveDiagnosticsLocked(
                SupabaseAuthDiagnostics(
                    status: .signedIn,
                    supabaseUserID: session.userID,
                    accessTokenPresent: session.hasAccessToken,
                    refreshTokenPresent: session.refreshToken != nil,
                    tokenExpiresAt: session.expiresAt,
                    lastErrorMessage: nil,
                    lastAuthAt: Date()
                )
            )
        }
    }

    public func clearSession(status: SupabaseAuthStatus = .signedOut) {
        withLock {
            defaults.removeObject(forKey: Self.sessionKey)
            saveDiagnosticsLocked(SupabaseAuthDiagnostics(status: status))
        }
    }

    public func loadDiagnostics() -> SupabaseAuthDiagnostics {
        withLock {
            guard let data = defaults.data(forKey: Self.diagnosticsKey),
                  let diagnostics = try? decoder.decode(SupabaseAuthDiagnostics.self, from: data) else {
                return .disabled
            }
            return diagnostics
        }
    }

    public func record(status: SupabaseAuthStatus, error: String? = nil, userID: String? = nil) {
        withLock {
            let session = loadSessionLocked()
            saveDiagnosticsLocked(
                SupabaseAuthDiagnostics(
                    status: status,
                    supabaseUserID: userID ?? session?.userID,
                    accessTokenPresent: session?.hasAccessToken == true,
                    refreshTokenPresent: session?.refreshToken != nil,
                    tokenExpiresAt: session?.expiresAt,
                    lastErrorMessage: error,
                    lastAuthAt: status == .signedIn ? Date() : loadDiagnosticsLocked().lastAuthAt
                )
            )
        }
    }

    private func loadSessionLocked() -> SupabaseAuthSession? {
        guard let data = defaults.data(forKey: Self.sessionKey),
              let session = try? decoder.decode(SupabaseAuthSession.self, from: data),
              session.hasAccessToken else {
            return nil
        }
        return session
    }

    private func loadDiagnosticsLocked() -> SupabaseAuthDiagnostics {
        guard let data = defaults.data(forKey: Self.diagnosticsKey),
              let diagnostics = try? decoder.decode(SupabaseAuthDiagnostics.self, from: data) else {
            return .disabled
        }
        return diagnostics
    }

    private func saveDiagnosticsLocked(_ diagnostics: SupabaseAuthDiagnostics) {
        guard let data = try? encoder.encode(diagnostics) else { return }
        defaults.set(data, forKey: Self.diagnosticsKey)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

public struct SupabaseAppleAuthBridgeResult: Equatable, Sendable {
    public var didCreateSession: Bool
    public var message: String
    public var supabaseUserID: String?

    public init(didCreateSession: Bool, message: String, supabaseUserID: String?) {
        self.didCreateSession = didCreateSession
        self.message = message
        self.supabaseUserID = supabaseUserID
    }
}
