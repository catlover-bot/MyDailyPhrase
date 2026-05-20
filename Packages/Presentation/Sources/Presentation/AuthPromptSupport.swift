import Foundation

public enum AuthPromptSurface: String, Sendable {
    case profile
    case settings
    case community
    case follow
    case directMessage

    public var title: String {
        switch self {
        case .profile:
            return "アカウントでつながる"
        case .settings:
            return "ログイン / 新規登録"
        case .community:
            return "コミュニティをもっと使いやすく"
        case .follow:
            return "フォローはログイン後に使えます"
        case .directMessage:
            return "DMは相互フォローになると使えます"
        }
    }

    public var message: String {
        switch self {
        case .profile:
            return "ログインすると、プロフィール共有・フォロー・DM・コミュニティ参加を使いやすくできます。日記は自動で公開されません。"
        case .settings:
            return "Appleでログインすると、プロフィールと安全なSNS機能をこの端末で確認できます。基本機能はログインなしでも使えます。"
        case .community:
            return "ログインすると参加中の部屋、フォロー、相互フォローDMが分かりやすくなります。参加は無料です。"
        case .follow:
            return "プロフィールカードをフォローして、相互フォローになるとDMの下書きを使えます。"
        case .directMessage:
            return "不快な相手はブロック・通報できます。日記の回答は自動で送信されません。"
        }
    }
}

public struct AuthPromptModel: Equatable, Sendable {
    public let title: String
    public let message: String
    public let primaryActionTitle: String
    public let privacyNote: String

    public init(
        title: String,
        message: String,
        primaryActionTitle: String = "ログイン / 新規登録",
        privacyNote: String = "日記の回答は自動で公開されません。共有する内容は自分で選べます。"
    ) {
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.privacyNote = privacyNote
    }
}

public enum AuthPromptSupport {
    public static func canUseSocialActions(
        isAuthenticated: Bool,
        isGuest: Bool,
        hasLinkedAccount: Bool
    ) -> Bool {
        (isAuthenticated && !isGuest) || hasLinkedAccount
    }

    public static func prompt(
        for surface: AuthPromptSurface,
        isSignedIn: Bool,
        isGuest: Bool
    ) -> AuthPromptModel? {
        guard !isSignedIn || isGuest else { return nil }
        return AuthPromptModel(
            title: surface.title,
            message: surface.message
        )
    }
}
