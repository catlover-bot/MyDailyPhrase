import Foundation

public enum CommunityVisibility: String, Codable, CaseIterable, Sendable {
    case localOnly
    case inviteOnly
    case publicDisabled
}

public enum CommunityPromptSchedule: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
}

public enum CommunityCategory: String, Codable, CaseIterable, Sendable {
    case games
    case study
    case music
    case anime
    case books
    case fitness
    case dailyLife
    case custom
}

public struct CommunityPromptPolicy: Codable, Equatable, Sendable {
    public enum Tone: String, Codable, CaseIterable, Sendable {
        case casual
        case deep
        case fun
        case nostalgic
        case challenge
    }

    public enum PromptLength: String, Codable, CaseIterable, Sendable {
        case short
        case medium
    }

    public enum PrivacyLevel: String, Codable, CaseIterable, Sendable {
        case safeToShare
        case privateReflection
    }

    public enum AnswerStyle: String, Codable, CaseIterable, Sendable {
        case onePhrase
        case shortMemo
        case ranking
        case recommendation
    }

    public enum Language: String, Codable, CaseIterable, Sendable {
        case ja
    }

    public var tone: Tone
    public var promptLength: PromptLength
    public var privacyLevel: PrivacyLevel
    public var answerStyle: AnswerStyle
    public var language: Language

    public init(
        tone: Tone = .casual,
        promptLength: PromptLength = .short,
        privacyLevel: PrivacyLevel = .safeToShare,
        answerStyle: AnswerStyle = .onePhrase,
        language: Language = .ja
    ) {
        self.tone = tone
        self.promptLength = promptLength
        self.privacyLevel = privacyLevel
        self.answerStyle = answerStyle
        self.language = language
    }
}

public struct CommunityTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var category: CommunityCategory
    public var emoji: String
    public var createdAt: Date
    public var creatorDisplayName: String?
    public var creatorId: String?
    public var visibility: CommunityVisibility
    public var promptPolicy: CommunityPromptPolicy
    public var promptSchedule: CommunityPromptSchedule
    public var promptPacks: [String]
    public var themeDecorationId: String?
    public var allowedTags: [String]
    public var blockedWords: [String]
    public var isOfficialPreset: Bool
    public var requiresCreatorPassToCreate: Bool
    public var isJoined: Bool
    public var joinedAt: Date?
    public var customPromptSeeds: [String]
    public var pinnedNextPromptText: String?

    public init(
        id: String,
        name: String,
        description: String,
        category: CommunityCategory,
        emoji: String,
        createdAt: Date,
        creatorDisplayName: String? = nil,
        creatorId: String? = nil,
        visibility: CommunityVisibility = .inviteOnly,
        promptPolicy: CommunityPromptPolicy = CommunityPromptPolicy(),
        promptSchedule: CommunityPromptSchedule = .daily,
        promptPacks: [String] = [],
        themeDecorationId: String? = nil,
        allowedTags: [String] = [],
        blockedWords: [String] = [],
        isOfficialPreset: Bool = false,
        requiresCreatorPassToCreate: Bool = false,
        isJoined: Bool = false,
        joinedAt: Date? = nil,
        customPromptSeeds: [String] = [],
        pinnedNextPromptText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.emoji = emoji
        self.createdAt = createdAt
        self.creatorDisplayName = creatorDisplayName
        self.creatorId = creatorId
        self.visibility = visibility
        self.promptPolicy = promptPolicy
        self.promptSchedule = promptSchedule
        self.promptPacks = promptPacks
        self.themeDecorationId = themeDecorationId
        self.allowedTags = allowedTags
        self.blockedWords = blockedWords
        self.isOfficialPreset = isOfficialPreset
        self.requiresCreatorPassToCreate = requiresCreatorPassToCreate
        self.isJoined = isJoined
        self.joinedAt = joinedAt
        self.customPromptSeeds = customPromptSeeds
        self.pinnedNextPromptText = pinnedNextPromptText
    }

    public mutating func normalize() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmedName.isEmpty ? "新しいコミュニティ" : String(trimmedName.prefix(36))

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        description = String(trimmedDescription.prefix(140))

        let normalizedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        emoji = normalizedEmoji.isEmpty ? Self.defaultEmoji(for: category) : String(normalizedEmoji.prefix(2))

        creatorDisplayName = creatorDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        creatorId = creatorId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        themeDecorationId = themeDecorationId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        allowedTags = Self.normalizeTokens(allowedTags, maxCount: 8, lowercased: true)
        blockedWords = Self.normalizeTokens(blockedWords, maxCount: 12, lowercased: true)
        promptPacks = Self.normalizeTokens(promptPacks, maxCount: 8, lowercased: true)
        customPromptSeeds = Self.normalizeLines(customPromptSeeds, maxCount: 12, maxLength: 60)
        let trimmedPinnedPrompt = pinnedNextPromptText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedPinnedPrompt, !trimmedPinnedPrompt.isEmpty {
            pinnedNextPromptText = String(trimmedPinnedPrompt.prefix(70))
        } else {
            pinnedNextPromptText = nil
        }

        if !isJoined {
            joinedAt = nil
        } else if joinedAt == nil {
            joinedAt = createdAt
        }
    }

    public static func defaultEmoji(for category: CommunityCategory) -> String {
        switch category {
        case .games:
            return "🎮"
        case .study:
            return "📚"
        case .music:
            return "🎵"
        case .anime:
            return "🌟"
        case .books:
            return "📖"
        case .fitness:
            return "💪"
        case .dailyLife:
            return "☕️"
        case .custom:
            return "✨"
        }
    }

    private static func normalizeTokens(
        _ values: [String],
        maxCount: Int,
        lowercased: Bool
    ) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []

        for raw in values {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if lowercased {
                value = value.lowercased()
            }
            guard !value.isEmpty else { continue }
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            cleaned.append(String(value.prefix(24)))
            if cleaned.count >= maxCount {
                break
            }
        }

        return cleaned
    }

    private static func normalizeLines(
        _ values: [String],
        maxCount: Int,
        maxLength: Int
    ) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []

        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            cleaned.append(String(value.prefix(maxLength)))
            if cleaned.count >= maxCount {
                break
            }
        }

        return cleaned
    }
}

public enum CommunityPromptCreatedBy: String, Codable, CaseIterable, Sendable {
    case system
    case creator
    case localGenerated
}

public struct CommunityPrompt: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var communityId: String
    public var text: String
    public var category: CommunityCategory
    public var tags: [String]
    public var dateKey: String?
    public var weekKey: String?
    public var shareSafe: Bool
    public var createdBy: CommunityPromptCreatedBy
    public var isActive: Bool
    public var answerStyle: CommunityPromptPolicy.AnswerStyle

    public init(
        id: String,
        communityId: String,
        text: String,
        category: CommunityCategory,
        tags: [String],
        dateKey: String? = nil,
        weekKey: String? = nil,
        shareSafe: Bool,
        createdBy: CommunityPromptCreatedBy,
        isActive: Bool = true,
        answerStyle: CommunityPromptPolicy.AnswerStyle
    ) {
        self.id = id
        self.communityId = communityId
        self.text = text
        self.category = category
        self.tags = tags
        self.dateKey = dateKey
        self.weekKey = weekKey
        self.shareSafe = shareSafe
        self.createdBy = createdBy
        self.isActive = isActive
        self.answerStyle = answerStyle
    }

    public var promptKey: String {
        weekKey ?? dateKey ?? id
    }
}

public struct CommunityPromptBundle: Equatable, Sendable {
    public var primary: CommunityPrompt
    public var alternates: [CommunityPrompt]

    public init(primary: CommunityPrompt, alternates: [CommunityPrompt]) {
        self.primary = primary
        self.alternates = alternates
    }
}

public struct CommunityResponse: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var communityId: String
    public var promptKey: String
    public var promptText: String
    public var answer: String
    public var updatedAt: Date

    public init(
        id: String? = nil,
        communityId: String,
        promptKey: String,
        promptText: String,
        answer: String,
        updatedAt: Date
    ) {
        self.communityId = communityId
        self.promptKey = promptKey
        self.promptText = promptText
        self.answer = answer
        self.updatedAt = updatedAt
        self.id = id ?? Self.makeID(communityId: communityId, promptKey: promptKey)
    }

    public mutating func normalize() {
        promptText = String(promptText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        answer = String(answer.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        id = Self.makeID(communityId: communityId, promptKey: promptKey)
    }

    public static func makeID(communityId: String, promptKey: String) -> String {
        "\(communityId)|\(promptKey)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
