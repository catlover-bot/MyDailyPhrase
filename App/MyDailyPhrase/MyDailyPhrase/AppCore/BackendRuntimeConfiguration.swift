import Foundation
import Data
import Domain

struct BackendRuntimeConfiguration: Sendable {
    let supabaseConfiguration: SupabaseBackendConfiguration

    func diagnostics(
        profileSyncDiagnostics: ProfileSyncDiagnostics = .localFallback,
        connectionDiagnostics: BackendConnectionDiagnostics = .localFallback
    ) -> SettingsBackendContext {
        SettingsBackendContext(
            snapshot: BackendDiagnosticsSnapshot(
                configuration: supabaseConfiguration,
                profileSyncDiagnostics: profileSyncDiagnostics,
                connectionDiagnostics: connectionDiagnostics
            )
        )
    }

    static func load(from bundle: Bundle = .main) -> BackendRuntimeConfiguration {
        BackendRuntimeConfiguration(
            supabaseConfiguration: SupabaseBackendConfiguration.make(
                isEnabledConfigured: bundle.boolValue(forInfoDictionaryKey: "SUPABASE_BACKEND_ENABLED") ?? false,
                projectURLString: bundle.stringValue(forInfoDictionaryKey: "SUPABASE_URL"),
                anonKey: bundle.stringValue(forInfoDictionaryKey: "SUPABASE_ANON_KEY"),
                schemaVersion: bundle.stringValue(forInfoDictionaryKey: "SUPABASE_SCHEMA_VERSION") ?? "2026-05-21"
            )
        )
    }
}

struct SettingsBackendContext: Sendable {
    let provider: String
    let statusText: String
    let backendModeText: String
    let activeModeText: String
    let projectURLHost: String
    let anonKeyConfigured: Bool
    let keyType: String
    let keySafePrefix: String
    let schemaVersion: String
    let profilesTableName: String
    let connectionStatus: String
    let lastConnectionError: String
    let lastConnectionCheckedAt: String
    let localFallbackEnabled: Bool
    let publicFeedEnabled: Bool
    let commentsEnabled: Bool
    let rankingEnabled: Bool
    let dmPolicy: String
    let secretsInRepository: Bool
    let profileSyncStatus: String
    let lastBackendError: String
    let lastProfileSyncAt: String
    let diagnosticsReportText: String

    init(snapshot: BackendDiagnosticsSnapshot) {
        self.provider = snapshot.provider
        self.statusText = snapshot.status.label
        self.backendModeText = snapshot.backendModeLabel
        self.activeModeText = snapshot.activeMode.rawValue
        self.projectURLHost = snapshot.projectURLHost ?? "未設定"
        self.anonKeyConfigured = snapshot.anonKeyConfigured
        self.keyType = snapshot.keyType
        self.keySafePrefix = snapshot.keySafePrefix
        self.schemaVersion = snapshot.schemaVersion
        self.profilesTableName = snapshot.profilesTableName
        self.connectionStatus = snapshot.connectionStatus.rawValue
        self.lastConnectionError = snapshot.lastConnectionError ?? "なし"
        self.lastConnectionCheckedAt = snapshot.lastConnectionCheckedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし"
        self.localFallbackEnabled = snapshot.localFallbackEnabled
        self.publicFeedEnabled = snapshot.publicFeedEnabled
        self.commentsEnabled = snapshot.commentsEnabled
        self.rankingEnabled = snapshot.rankingEnabled
        self.dmPolicy = snapshot.dmPolicy
        self.secretsInRepository = snapshot.secretsInRepository
        self.profileSyncStatus = snapshot.profileSyncStatus.rawValue
        self.lastBackendError = snapshot.lastBackendError ?? "なし"
        self.lastProfileSyncAt = snapshot.lastProfileSyncAt.map { ISO8601DateFormatter().string(from: $0) } ?? "なし"
        self.diagnosticsReportText = snapshot.reportText
    }

    static let localFallback = SettingsBackendContext(
        snapshot: BackendDiagnosticsSnapshot(
            configuration: SupabaseBackendConfiguration(
                isEnabledConfigured: false,
                projectURL: nil,
                anonKey: nil
            )
        )
    )
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        if let value = object(forInfoDictionaryKey: key) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func boolValue(forInfoDictionaryKey key: String) -> Bool? {
        if let number = object(forInfoDictionaryKey: key) as? NSNumber {
            return number.boolValue
        }
        guard let raw = stringValue(forInfoDictionaryKey: key)?.lowercased() else {
            return nil
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }
}
