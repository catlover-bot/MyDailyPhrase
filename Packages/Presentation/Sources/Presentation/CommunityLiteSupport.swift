import Foundation
import Domain

public enum ReleaseFeatureAvailability {
    public static let paidGachaEnabled = true
    public static let publicCommunityEnabled = false
    public static let communityLiteEnabled = true
    public static let gameCommunityEnabled = true
    public static let socialGraphEnabled = true
    public static let publicUserDiscoveryEnabled = false
    public static let dmEnabled = true
    public static let publicDMEnabled = false
    public static let creatorPassEnabled = true
    public static let creatorCommunityCreationEnabled = true
    public static let creatorCommunityLocalDraftEnabled = true
    public static let nativeSharingEnabled = true
    public static let themePreviewEnabled = true
}

public enum CreatorEntitlementSource: String, Equatable, Sendable {
    case none
    case storeKit
    case debugOverride
    case localMock
}

public struct CreatorEntitlementState: Equatable, Sendable {
    public let hasCreatorPass: Bool
    public let canCreateCommunity: Bool
    public let entitlementSource: CreatorEntitlementSource

    public init(
        hasCreatorPass: Bool,
        canCreateCommunity: Bool,
        entitlementSource: CreatorEntitlementSource
    ) {
        self.hasCreatorPass = hasCreatorPass
        self.canCreateCommunity = canCreateCommunity
        self.entitlementSource = entitlementSource
    }
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

    public static func creatorEntitlementState(
        creatorPassEnabled: Bool,
        creatorCommunityCreationEnabled: Bool,
        creatorCommunityLocalDraftEnabled: Bool,
        storeKitEntitled: Bool,
        debugOverride: Bool
    ) -> CreatorEntitlementState {
        if debugOverride && creatorCommunityLocalDraftEnabled {
            return CreatorEntitlementState(
                hasCreatorPass: true,
                canCreateCommunity: true,
                entitlementSource: .debugOverride
            )
        }

        if storeKitEntitled {
            return CreatorEntitlementState(
                hasCreatorPass: true,
                canCreateCommunity: creatorPassEnabled && creatorCommunityCreationEnabled,
                entitlementSource: .storeKit
            )
        }

        return CreatorEntitlementState(
            hasCreatorPass: false,
            canCreateCommunity: false,
            entitlementSource: .none
        )
    }

    public static func officialPresetCommunities() -> [CommunityTemplate] {
        [
            CommunityTemplate(
                id: "official.games.general",
                name: "ゲーム好きの部屋",
                description: "最近遊んだ一本や推しキャラについて、気軽にひとこと残せる定番ルームです。",
                category: .games,
                emoji: "🎮",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .casual,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .onePhrase
                ),
                promptSchedule: .daily,
                promptPacks: [],
                themeDecorationId: "arcade",
                allowedTags: ["games", "general"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.rpg",
                name: "RPG酒場",
                description: "旅、仲間、世界観。RPGの余韻をゆっくり語れる、物語好きのための部屋です。",
                category: .games,
                emoji: "🗺️",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .deep,
                    promptLength: .medium,
                    privacyLevel: .safeToShare,
                    answerStyle: .shortMemo
                ),
                promptSchedule: .weekly,
                promptPacks: ["retro"],
                themeDecorationId: "retro",
                allowedTags: ["games", "rpg", "story"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.fps",
                name: "FPSロビー",
                description: "対戦の反省やクラッチの余韻を、短い言葉で整えるロビー型のゲーム部屋です。",
                category: .games,
                emoji: "🎯",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .challenge,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .ranking
                ),
                promptSchedule: .daily,
                promptPacks: ["matrix"],
                themeDecorationId: "matrix",
                allowedTags: ["games", "fps", "competitive"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.nintendo",
                name: "任天堂好きの部屋",
                description: "明るく語りやすいお題で、思い出や好きなキャラを残せます。",
                category: .games,
                emoji: "🍄",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .nostalgic,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .recommendation
                ),
                promptSchedule: .weekly,
                promptPacks: [],
                themeDecorationId: "sakura",
                allowedTags: ["games", "nintendo"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.indie",
                name: "インディーゲーム発掘部",
                description: "小さな傑作や雰囲気ゲーを静かに持ち寄る、発見好きのためのコミュニティです。",
                category: .games,
                emoji: "🌙",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .deep,
                    promptLength: .medium,
                    privacyLevel: .safeToShare,
                    answerStyle: .recommendation
                ),
                promptSchedule: .weekly,
                promptPacks: [],
                themeDecorationId: "moonlit",
                allowedTags: ["games", "indie"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.backlog",
                name: "積みゲー消化部",
                description: "今週ひらきたい一本や、少しだけ進めたいゲームをゆるく残す部屋です。",
                category: .games,
                emoji: "📦",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .challenge,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .onePhrase
                ),
                promptSchedule: .daily,
                promptPacks: [],
                themeDecorationId: "graphite",
                allowedTags: ["games", "backlog"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.retro",
                name: "レトロゲーム部",
                description: "昔のハードやドット絵の思い出を、やわらかく語れるクラシックな部屋です。",
                category: .games,
                emoji: "🕹️",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .nostalgic,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .shortMemo
                ),
                promptSchedule: .weekly,
                promptPacks: ["retro", "arcade"],
                themeDecorationId: "retro",
                allowedTags: ["games", "retro"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.character",
                name: "推しキャラ語り部",
                description: "好きなキャラや世界観に絞って、気持ちを短く残すための部屋です。",
                category: .games,
                emoji: "💫",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .fun,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .onePhrase
                ),
                promptSchedule: .daily,
                promptPacks: [],
                themeDecorationId: "stardust",
                allowedTags: ["games", "character"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.musicgame",
                name: "音ゲー部",
                description: "譜面、スコア、好きな一曲。音ゲーの気分を気軽に共有できる部屋です。",
                category: .games,
                emoji: "🎼",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .fun,
                    promptLength: .short,
                    privacyLevel: .safeToShare,
                    answerStyle: .ranking
                ),
                promptSchedule: .daily,
                promptPacks: [],
                themeDecorationId: "neon",
                allowedTags: ["games", "musicgame"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            ),
            CommunityTemplate(
                id: "official.games.competitive",
                name: "対戦ゲーム反省会",
                description: "勝ち筋や反省を落ち着いて振り返る、公開フィードなしの振り返り部屋です。",
                category: .games,
                emoji: "🔥",
                createdAt: .distantPast,
                creatorDisplayName: "ひとこと日記",
                creatorId: "official",
                visibility: .inviteOnly,
                promptPolicy: CommunityPromptPolicy(
                    tone: .challenge,
                    promptLength: .medium,
                    privacyLevel: .privateReflection,
                    answerStyle: .shortMemo
                ),
                promptSchedule: .weekly,
                promptPacks: ["matrix"],
                themeDecorationId: "volt",
                allowedTags: ["games", "competitive", "fps"],
                blockedWords: [],
                isOfficialPreset: true,
                requiresCreatorPassToCreate: false,
                isJoined: false
            )
        ]
    }

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

    public static func communityPromptShareText(
        appDisplayName: String = "ひとこと日記",
        community: CommunityTemplate,
        prompt: CommunityPrompt,
        answer: String?,
        includeAnswer: Bool,
        reaction: CommunityLiteReactionStamp
    ) -> String {
        var lines = [
            appDisplayName,
            "\(community.emoji) \(community.name)",
            prompt.text,
            "\(reaction.rawValue) コミュニティお題"
        ]
        if includeAnswer,
           let answer = trimmed(answer),
           !answer.isEmpty {
            lines.append("一言: \(answer)")
        }
        lines.append("#ひとこと日記")
        if community.category == .games {
            lines.append("#ゲーム日記")
            lines.append("#今日のゲームお題")
        }
        return lines.joined(separator: "\n")
    }

    public static func joinedCommunityShareText(
        appDisplayName: String = "ひとこと日記",
        community: CommunityTemplate
    ) -> String {
        var lines = [
            appDisplayName,
            "\(community.emoji) \(community.name) に参加しました",
            community.description,
            "#ひとこと日記"
        ]
        if community.category == .games {
            lines.append("#ゲーム日記")
        }
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
