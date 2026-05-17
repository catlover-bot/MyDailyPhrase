import Foundation

public enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case signInWithApple
    case google
    case guest
    case localDeveloperPreview
    case x

    public var displayName: String {
        switch self {
        case .signInWithApple:
            return "Apple"
        case .google:
            return "Google"
        case .guest:
            return "ゲスト"
        case .localDeveloperPreview:
            return "開発者プレビュー"
        case .x:
            return "X"
        }
    }

    public var linkedAuthProviderValue: String? {
        switch self {
        case .signInWithApple:
            return LinkedAuthProvider.apple.rawValue
        case .google:
            return LinkedAuthProvider.google.rawValue
        case .x:
            return LinkedAuthProvider.x.rawValue
        case .guest, .localDeveloperPreview:
            return nil
        }
    }

    public static func fromLinkedAuthProvider(_ rawValue: String?) -> AuthProvider? {
        guard let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !normalized.isEmpty else {
            return nil
        }

        switch normalized {
        case LinkedAuthProvider.apple.rawValue:
            return .signInWithApple
        case LinkedAuthProvider.google.rawValue:
            return .google
        case LinkedAuthProvider.x.rawValue:
            return .x
        default:
            return nil
        }
    }
}

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case user
    case creator
    case admin

    public var label: String {
        switch self {
        case .user:
            return "ユーザー"
        case .creator:
            return "Creator"
        case .admin:
            return "管理者"
        }
    }
}

public enum AdminCapability: String, Codable, CaseIterable, Sendable {
    case accessAllFeatures
    case manageCommunities
    case previewAllItems
    case bypassCreatorPassForAdmin
    case viewDiagnostics
    case moderateUsers
    case resetLocalDemoData
    case grantLocalTicketsForTesting

    public var label: String {
        switch self {
        case .accessAllFeatures:
            return "全機能アクセス"
        case .manageCommunities:
            return "コミュニティ管理"
        case .previewAllItems:
            return "全アイテム確認"
        case .bypassCreatorPassForAdmin:
            return "Creator Pass バイパス"
        case .viewDiagnostics:
            return "診断表示"
        case .moderateUsers:
            return "モデレーション"
        case .resetLocalDemoData:
            return "ローカルデータ初期化"
        case .grantLocalTicketsForTesting:
            return "テストチケット付与"
        }
    }

    public static let fullAdminSet: Set<AdminCapability> = Set(Self.allCases)
}

public struct AuthUser: Codable, Equatable, Sendable {
    public let id: String
    public let providerUserID: String?
    public let displayName: String
    public let email: String?
    public let provider: AuthProvider

    public init(
        id: String,
        providerUserID: String? = nil,
        displayName: String,
        email: String? = nil,
        provider: AuthProvider
    ) {
        self.id = id
        self.providerUserID = providerUserID
        self.displayName = displayName
        self.email = email
        self.provider = provider
    }
}

public struct AuthSession: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let user: AuthUser
    public let roles: [UserRole]
    public let adminCapabilities: [AdminCapability]
    public let startedAt: Date
    public let refreshedAt: Date
    public let requiresProfileSetup: Bool

    public init(
        id: String = UUID().uuidString,
        user: AuthUser,
        roles: [UserRole] = [.user],
        adminCapabilities: [AdminCapability] = [],
        startedAt: Date = Date(),
        refreshedAt: Date = Date(),
        requiresProfileSetup: Bool = false
    ) {
        self.id = id
        self.user = user
        self.roles = Array(Set(roles)).sorted { $0.rawValue < $1.rawValue }
        self.adminCapabilities = Array(Set(adminCapabilities)).sorted { $0.rawValue < $1.rawValue }
        self.startedAt = startedAt
        self.refreshedAt = refreshedAt
        self.requiresProfileSetup = requiresProfileSetup
    }

    public var isGuest: Bool {
        user.provider == .guest
    }

    public var isAdmin: Bool {
        roles.contains(.admin) || !adminCapabilities.isEmpty
    }
}

public enum AuthError: Error, LocalizedError, Equatable, Sendable {
    case providerNotConfigured(AuthProvider)
    case providerUnavailable(AuthProvider)
    case cancelled(AuthProvider)
    case invalidCredential
    case sessionUnavailable
    case accountDeletionUnavailable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let provider):
            return "\(provider.displayName)ログインはまだ準備中です"
        case .providerUnavailable(let provider):
            return "\(provider.displayName)ログインは現在利用できません"
        case .cancelled(let provider):
            return "\(provider.displayName)ログインをキャンセルしました"
        case .invalidCredential:
            return "認証情報を確認できませんでした"
        case .sessionUnavailable:
            return "ログイン状態を確認できませんでした"
        case .accountDeletionUnavailable:
            return "アカウント削除は現在サポート窓口で案内しています"
        case .unknown(let message):
            return message
        }
    }
}

public enum AuthState: Equatable, Sendable {
    case loading
    case signedOut
    case signedIn(AuthSession)
    case guest(AuthSession)
    case needsProfileSetup(AuthSession)
    case failed(AuthError)

    public var session: AuthSession? {
        switch self {
        case .signedIn(let session), .guest(let session), .needsProfileSetup(let session):
            return session
        case .loading, .signedOut, .failed:
            return nil
        }
    }
}
