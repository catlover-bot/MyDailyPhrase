import Foundation

public enum ReleaseFeatureAvailability {
    public static let paidGachaEnabled = false
    public static let publicCommunityEnabled = false
    public static let communityLiteEnabled = true
    public static let nativeSharingEnabled = true
    public static let themePreviewEnabled = true
}

public enum CommunityLiteReactionStamp: String, CaseIterable, Codable, Identifiable, Sendable {
    case thumbsUp = "👍"
    case moon = "🌙"
    case sparkles = "✨"
    case fire = "🔥"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .thumbsUp:
            return "いいね"
        case .moon:
            return "夜"
        case .sparkles:
            return "きらめき"
        case .fire:
            return "やる気"
        }
    }
}

public struct CommunityLiteWeeklyChallenge: Equatable, Sendable {
    public let weekKey: String
    public let title: String
    public let prompt: String
    public let badgeTitle: String
    public let hashtag: String
    public let shareHook: String

    public init(
        weekKey: String,
        title: String,
        prompt: String,
        badgeTitle: String,
        hashtag: String,
        shareHook: String
    ) {
        self.weekKey = weekKey
        self.title = title
        self.prompt = prompt
        self.badgeTitle = badgeTitle
        self.hashtag = hashtag
        self.shareHook = shareHook
    }
}

public enum CommunityLiteSupport {
    private static let challengeTemplates: [(title: String, prompt: String, badge: String, shareHook: String)] = [
        ("今週のやさしい一言", "今週、自分にかけてあげたい言葉は？", "今週のテーマに参加", "今週のテーマに参加しました。"),
        ("小さな前進チャレンジ", "今週の小さな前進をひとことで残すなら？", "前進のしるし", "小さな前進を記録しました。"),
        ("感謝のメモ", "今週、静かに感謝したいことは？", "ありがとうの余韻", "感謝のひとことを残しました。"),
        ("夜のふりかえり", "今週の終わりに、心に残った景色は？", "夜の参加バッジ", "今週の夜のふりかえりに参加しました。"),
        ("ことばの旅", "今週の自分をひとことで表すなら？", "ことばの旅人", "今週のことばの旅に参加しました。"),
        ("明日へのメモ", "来週の自分に渡したい一言は？", "明日への手紙", "来週へ向けたひとことを残しました。")
    ]

    public static func weekKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    public static func challenge(
        for date: Date,
        calendar: Calendar = CommunityLiteSupport.makeDefaultCalendar()
    ) -> CommunityLiteWeeklyChallenge {
        let key = weekKey(for: date, calendar: calendar)
        let index = Int(stableHash64(key) % UInt64(challengeTemplates.count))
        let template = challengeTemplates[index]
        return CommunityLiteWeeklyChallenge(
            weekKey: key,
            title: template.title,
            prompt: template.prompt,
            badgeTitle: template.badge,
            hashtag: "#ひとこと日記",
            shareHook: template.shareHook
        )
    }

    public static func weeklyChallengeShareText(
        appDisplayName: String = "ひとこと日記",
        challenge: CommunityLiteWeeklyChallenge,
        displayName: String,
        profileTitle: String?,
        reaction: CommunityLiteReactionStamp,
        answer: String?,
        includeAnswer: Bool
    ) -> String {
        var lines = [
            appDisplayName,
            challenge.title,
            challenge.shareHook,
            "\(reaction.rawValue) \(challenge.badgeTitle)"
        ]
        if let profileTitle, !profileTitle.isEmpty {
            lines.append("称号: \(profileTitle)")
        }
        if includeAnswer,
           let trimmed = trimmed(answer),
           !trimmed.isEmpty {
            lines.append("一言: \(trimmed)")
        }
        lines.append(challenge.hashtag)
        lines.append("by \(normalizedName(displayName))")
        return lines.joined(separator: "\n")
    }

    public static func profileCardShareText(
        appDisplayName: String = "ひとこと日記",
        displayName: String,
        profileTitle: String?,
        streak: Int?,
        reaction: CommunityLiteReactionStamp,
        includeStreak: Bool
    ) -> String {
        var lines = [
            appDisplayName,
            "\(reaction.rawValue) プロフィールカード",
            normalizedName(displayName)
        ]
        if let profileTitle, !profileTitle.isEmpty {
            lines.append(profileTitle)
        }
        if includeStreak, let streak {
            lines.append("連続記録 \(streak)日")
        }
        lines.append("#ひとこと日記")
        return lines.joined(separator: "\n")
    }

    public static func achievementShareText(
        appDisplayName: String = "ひとこと日記",
        displayName: String,
        streak: Int,
        profileTitle: String?,
        reaction: CommunityLiteReactionStamp
    ) -> String {
        var lines = [
            appDisplayName,
            "\(reaction.rawValue) 続けている記録",
            "連続記録 \(max(0, streak))日"
        ]
        if let profileTitle, !profileTitle.isEmpty {
            lines.append(profileTitle)
        }
        lines.append("by \(normalizedName(displayName))")
        lines.append("#ひとこと日記")
        return lines.joined(separator: "\n")
    }

    public static func makeDefaultCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    private static func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func normalizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Me" : trimmed
    }

    private static func trimmed(_ raw: String?) -> String? {
        raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
