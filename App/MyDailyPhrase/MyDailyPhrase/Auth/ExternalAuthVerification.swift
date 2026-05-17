import Foundation
import Domain

enum ExternalAuthProvider: String, CaseIterable, Sendable {
    case google
    case x

    var linkedAuthProvider: LinkedAuthProvider {
        switch self {
        case .google:
            return .google
        case .x:
            return .x
        }
    }

    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .x:
            return "X"
        }
    }
}

struct ExternalAuthVerificationRequest: Sendable {
    let provider: ExternalAuthProvider
    let token: String
}

struct VerifiedExternalAuthIdentity: Sendable {
    let provider: ExternalAuthProvider
    let subject: String
    let displayName: String?
    let email: String?
    let issuedAt: Date
}

enum ExternalAuthVerificationError: LocalizedError {
    case backendNotConfigured(provider: ExternalAuthProvider)
    case invalidTokenFormat
    case malformedResponse
    case transportFailure(reason: String)
    case serviceUnavailable(statusCode: Int, errorCode: String?, reason: String?)
    case verificationRejected(errorCode: String?, reason: String)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured(let provider):
            return "\(provider.displayName) のサーバー検証基盤が未設定です"
        case .invalidTokenFormat:
            return "認証トークン形式が不正です"
        case .malformedResponse:
            return "検証APIの応答形式が不正です"
        case .transportFailure(let reason):
            return "検証API通信に失敗しました: \(reason)"
        case .serviceUnavailable(let statusCode, let errorCode, let reason):
            if let mapped = Self.message(for: errorCode) {
                return mapped
            }
            if statusCode == 401 || statusCode == 403 {
                return "認証サーバー設定の確認が必要です。時間をおいて再試行してください"
            }
            if statusCode == 429 {
                return "リクエストが集中しています。少し待って再試行してください"
            }
            if let reason, !reason.isEmpty {
                return "検証APIエラー(\(statusCode)): \(reason)"
            }
            return "検証APIエラー(\(statusCode))"
        case .verificationRejected(let errorCode, let reason):
            if let mapped = Self.message(for: errorCode) {
                return mapped
            }
            return "サーバー検証に失敗しました: \(reason)"
        }
    }

    private static func message(for errorCode: String?) -> String? {
        guard let code = errorCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !code.isEmpty else {
            return nil
        }
        switch code {
        case "token_expired", "expired_token", "id_token_expired":
            return "認証の有効期限が切れました。もう一度ログインしてください"
        case "token_invalid", "invalid_token", "invalid_grant":
            return "認証情報が無効です。もう一度ログインしてください"
        case "token_revoked", "credential_revoked":
            return "連携資格が無効化されています。再連携してください"
        case "provider_mismatch":
            return "選択したログイン方法と認証情報が一致しません"
        case "provider_unsupported":
            return "このログイン方法は現在利用できません"
        case "rate_limited", "too_many_requests":
            return "リクエストが集中しています。少し待って再試行してください"
        case "service_unavailable", "upstream_unavailable", "maintenance":
            return "認証サービスが利用しづらい状態です。時間をおいて再試行してください"
        default:
            return nil
        }
    }
}

protocol ExternalAuthTokenVerifier: Sendable {
    func verify(request: ExternalAuthVerificationRequest) async throws -> VerifiedExternalAuthIdentity
}

struct BackendPendingAuthTokenVerifier: ExternalAuthTokenVerifier {
    func verify(request: ExternalAuthVerificationRequest) async throws -> VerifiedExternalAuthIdentity {
        throw ExternalAuthVerificationError.backendNotConfigured(provider: request.provider)
    }
}

struct BackendAuthAPITokenVerifier: ExternalAuthTokenVerifier, @unchecked Sendable {
    struct Configuration: Sendable {
        let endpoint: URL
        let bearerToken: String?
        let timeoutSeconds: TimeInterval

        init(
            endpoint: URL,
            bearerToken: String? = nil,
            timeoutSeconds: TimeInterval = 8.0
        ) {
            self.endpoint = endpoint
            self.bearerToken = bearerToken
            self.timeoutSeconds = max(2.0, timeoutSeconds)
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func verify(request: ExternalAuthVerificationRequest) async throws -> VerifiedExternalAuthIdentity {
        let trimmedToken = request.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw ExternalAuthVerificationError.invalidTokenFormat
        }

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("1", forHTTPHeaderField: "X-MyDailyPhrase-Auth-Schema")

        if let bearer = configuration.bearerToken?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !bearer.isEmpty {
            urlRequest.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }

        let payload = AuthVerifyRequestV1(
            schemaVersion: 1,
            provider: request.provider.rawValue,
            providerToken: trimmedToken
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ExternalAuthVerificationError.transportFailure(reason: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ExternalAuthVerificationError.transportFailure(reason: "HTTPレスポンスを取得できませんでした")
        }

        guard (200...299).contains(http.statusCode) else {
            let error = parseServiceError(from: data)
            throw ExternalAuthVerificationError.serviceUnavailable(
                statusCode: http.statusCode,
                errorCode: error?.errorCode,
                reason: error?.reason
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto: AuthVerifyResponseV1
        do {
            dto = try decoder.decode(AuthVerifyResponseV1.self, from: data)
        } catch {
            throw ExternalAuthVerificationError.malformedResponse
        }

        guard dto.success else {
            throw ExternalAuthVerificationError.verificationRejected(
                errorCode: dto.errorCode,
                reason: dto.errorMessage ?? dto.errorCode ?? "rejected"
            )
        }

        let subject = dto.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let subject, !subject.isEmpty else {
            throw ExternalAuthVerificationError.malformedResponse
        }

        let provider = ExternalAuthProvider(rawValue: dto.provider.lowercased()) ?? request.provider
        guard let issuedAt = decodeIssuedAt(from: dto.issuedAt) else {
            throw ExternalAuthVerificationError.malformedResponse
        }

        return VerifiedExternalAuthIdentity(
            provider: provider,
            subject: subject,
            displayName: dto.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            email: dto.email?.trimmingCharacters(in: .whitespacesAndNewlines),
            issuedAt: issuedAt
        )
    }

    private func parseServiceError(from data: Data) -> ParsedServiceError? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let dto = try? decoder.decode(AuthVerifyErrorV1.self, from: data) {
            return ParsedServiceError(
                errorCode: dto.errorCode,
                reason: dto.message ?? dto.reason ?? dto.errorCode
            )
        }
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        let clipped = text.count <= 120 ? text : String(text.prefix(120))
        return ParsedServiceError(errorCode: nil, reason: clipped)
    }

    private func decodeIssuedAt(from raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if let date = Self.iso8601WithFractional.date(from: trimmed) {
            return date
        }
        return Self.iso8601.date(from: trimmed)
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

struct DevelopmentExternalAuthTokenVerifier: ExternalAuthTokenVerifier {
    func verify(request: ExternalAuthVerificationRequest) async throws -> VerifiedExternalAuthIdentity {
        let token = request.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ExternalAuthVerificationError.invalidTokenFormat
        }
        guard token.hasPrefix("dev_") else {
            throw ExternalAuthVerificationError.verificationRejected(
                errorCode: "token_invalid",
                reason: "開発用トークンは dev_ で始めてください"
            )
        }

        let suffix = String(token.suffix(16))
        let subject = "dev-\(request.provider.rawValue)-\(suffix)"
        return VerifiedExternalAuthIdentity(
            provider: request.provider,
            subject: subject,
            displayName: nil,
            email: nil,
            issuedAt: Date()
        )
    }
}

struct CompositeExternalAuthTokenVerifier: ExternalAuthTokenVerifier {
    private let verifiers: [any ExternalAuthTokenVerifier]

    init(verifiers: [any ExternalAuthTokenVerifier]) {
        self.verifiers = verifiers
    }

    func verify(request: ExternalAuthVerificationRequest) async throws -> VerifiedExternalAuthIdentity {
        var lastError: Error?
        for verifier in verifiers {
            do {
                return try await verifier.verify(request: request)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? ExternalAuthVerificationError.verificationRejected(errorCode: nil, reason: "no verifier")
    }
}

struct ExternalAuthRuntimeConfiguration: Sendable {
    let verificationEndpointURL: URL?
    let verificationBearerToken: String?
    let verificationTimeoutSeconds: TimeInterval
    let googleOAuthStartURL: URL?
    let xOAuthStartURL: URL?
    let oauthCallbackScheme: String?
    let guestModeEnabled: Bool
    let adminAppleUserIDs: Set<String>
    let adminEmails: Set<String>
    let allowsManualTokenInput: Bool
    let termsOfServiceURL: URL?
    let privacyPolicyURL: URL?
    let defaultSecurityLogRetentionDays: Int
    let maxSecurityLogRetentionDays: Int

    static func load(from bundle: Bundle = .main) -> ExternalAuthRuntimeConfiguration {
        let endpoint = normalizedVerifyEndpoint(from: bundle.urlValue(forInfoDictionaryKey: "AUTH_BACKEND_VERIFY_ENDPOINT"))
        let bearer = bundle.stringValue(forInfoDictionaryKey: "AUTH_BACKEND_VERIFY_BEARER")
        let timeout = bundle.doubleValue(forInfoDictionaryKey: "AUTH_BACKEND_TIMEOUT_SECONDS") ?? 8.0
        let googleOAuthStartURL = normalizedOAuthStartURL(from: bundle.urlValue(forInfoDictionaryKey: "AUTH_GOOGLE_OAUTH_START_URL"))
        let xOAuthStartURL = normalizedOAuthStartURL(from: bundle.urlValue(forInfoDictionaryKey: "AUTH_X_OAUTH_START_URL"))
        let callbackScheme = normalizedCallbackScheme(from: bundle.stringValue(forInfoDictionaryKey: "AUTH_OAUTH_CALLBACK_SCHEME"))
        let guestModeEnabled = bundle.boolValue(forInfoDictionaryKey: "AUTH_GUEST_MODE_ENABLED") ?? true
        let adminAppleUserIDs = normalizedAllowlistValues(from: bundle.stringValue(forInfoDictionaryKey: "AUTH_ADMIN_APPLE_USER_IDS"))
        let adminEmails = normalizedAllowlistValues(from: bundle.stringValue(forInfoDictionaryKey: "AUTH_ADMIN_EMAILS"))
        let allowsManualTokenInput = bundle.boolValue(forInfoDictionaryKey: "AUTH_ALLOW_MANUAL_TOKEN_INPUT") ?? true
        let terms = normalizedLegalURL(from: bundle.urlValue(forInfoDictionaryKey: "LEGAL_TERMS_URL"))
        let privacy = normalizedLegalURL(from: bundle.urlValue(forInfoDictionaryKey: "LEGAL_PRIVACY_POLICY_URL"))
        let retentionDefault = bundle.intValue(forInfoDictionaryKey: "SECURITY_LOG_RETENTION_DAYS_DEFAULT") ?? 90
        let retentionMax = bundle.intValue(forInfoDictionaryKey: "SECURITY_LOG_RETENTION_DAYS_MAX") ?? 365

        return ExternalAuthRuntimeConfiguration(
            verificationEndpointURL: endpoint,
            verificationBearerToken: bearer,
            verificationTimeoutSeconds: max(2.0, timeout),
            googleOAuthStartURL: googleOAuthStartURL,
            xOAuthStartURL: xOAuthStartURL,
            oauthCallbackScheme: callbackScheme,
            guestModeEnabled: guestModeEnabled,
            adminAppleUserIDs: adminAppleUserIDs,
            adminEmails: adminEmails,
            allowsManualTokenInput: allowsManualTokenInput,
            termsOfServiceURL: terms,
            privacyPolicyURL: privacy,
            defaultSecurityLogRetentionDays: min(max(7, retentionDefault), max(7, retentionMax)),
            maxSecurityLogRetentionDays: max(7, retentionMax)
        )
    }

    private static func normalizedVerifyEndpoint(from raw: URL?) -> URL? {
        guard var raw else { return nil }
        guard let scheme = raw.scheme?.lowercased(), scheme == "https" else {
            return nil
        }
        guard let host = raw.host?.lowercased(), !isPlaceholderHost(host) else {
            return nil
        }
        let path = raw.path.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty || path == "/" {
            raw.appendPathComponent("auth")
            raw.appendPathComponent("verify")
        }
        return raw
    }

    private static func normalizedOAuthStartURL(from raw: URL?) -> URL? {
        guard let raw else { return nil }
        guard let scheme = raw.scheme?.lowercased(), scheme == "https" else {
            return nil
        }
        guard let host = raw.host?.lowercased(), !isPlaceholderHost(host) else {
            return nil
        }
        return raw
    }

    private static func normalizedLegalURL(from raw: URL?) -> URL? {
        guard let raw else { return nil }
        guard let scheme = raw.scheme?.lowercased(), scheme == "https" else {
            return nil
        }
        guard let host = raw.host?.lowercased(), !isPlaceholderHost(host) else {
            return nil
        }
        return raw
    }

    private static func normalizedCallbackScheme(from raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else { return nil }
        // RFC 3986 scheme rule: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789+-.")
        guard raw.rangeOfCharacter(from: allowed.inverted) == nil else {
            return nil
        }
        guard let first = raw.unicodeScalars.first,
              CharacterSet.letters.contains(first) else {
            return nil
        }
        return raw
    }

    private static func normalizedAllowlistValues(from raw: String?) -> Set<String> {
        guard let raw else { return [] }
        return Set(
            raw
                .split { $0 == "," || $0 == "\n" || $0 == ";" }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    private static func isPlaceholderHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        if lowered == "example.com" || lowered.hasSuffix(".example") {
            return true
        }
        return lowered.contains("placeholder")
            || lowered.contains("changeme")
            || lowered.contains("your-domain")
    }
}

private struct AuthVerifyRequestV1: Encodable {
    let schemaVersion: Int
    let provider: String
    let providerToken: String
}

private struct AuthVerifyResponseV1: Decodable {
    let success: Bool
    let provider: String
    let subject: String?
    let issuedAt: String
    let displayName: String?
    let email: String?
    let errorCode: String?
    let errorMessage: String?
}

private struct AuthVerifyErrorV1: Decodable {
    let errorCode: String?
    let reason: String?
    let message: String?
}

private struct ParsedServiceError {
    let errorCode: String?
    let reason: String?
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        guard let raw = object(forInfoDictionaryKey: key) else { return nil }
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func intValue(forInfoDictionaryKey key: String) -> Int? {
        guard let raw = object(forInfoDictionaryKey: key) else { return nil }
        if let value = raw as? Int { return value }
        if let value = raw as? String { return Int(value) }
        return nil
    }

    func doubleValue(forInfoDictionaryKey key: String) -> Double? {
        guard let raw = object(forInfoDictionaryKey: key) else { return nil }
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? String { return Double(value) }
        return nil
    }

    func boolValue(forInfoDictionaryKey key: String) -> Bool? {
        guard let raw = object(forInfoDictionaryKey: key) else { return nil }
        if let value = raw as? Bool { return value }
        if let value = raw as? Int { return value != 0 }
        if let value = raw as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    func urlValue(forInfoDictionaryKey key: String) -> URL? {
        guard let value = stringValue(forInfoDictionaryKey: key) else { return nil }
        return URL(string: value)
    }
}
