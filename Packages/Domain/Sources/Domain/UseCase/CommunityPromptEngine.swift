import Foundation

public struct CommunityPromptEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func promptBundle(
        for community: CommunityTemplate,
        referenceDate: Date
    ) -> CommunityPromptBundle {
        var community = community
        community.normalize()

        let promptKey = makePromptKey(for: community, referenceDate: referenceDate)
        let shareSafe = community.promptPolicy.privacyLevel == .safeToShare

        if let pinned = sanitizedPinnedPrompt(for: community) {
            let prompt = makePrompt(
                community: community,
                promptKey: promptKey,
                referenceDate: referenceDate,
                candidate: PromptCandidate(
                    text: pinned,
                    tags: community.allowedTags,
                    createdBy: .creator
                ),
                shareSafe: shareSafe
            )
            return CommunityPromptBundle(primary: prompt, alternates: alternatePrompts(for: community, promptKey: promptKey, referenceDate: referenceDate, excluding: pinned, shareSafe: shareSafe))
        }

        let pool = promptPool(for: community)
        let primaryPool = pool.focused.isEmpty ? pool.all : pool.focused
        let primaryIndex = stableIndex(
            seed: "\(community.id)|\(promptKey)|primary",
            count: primaryPool.count
        )
        let primaryCandidate = primaryPool[primaryIndex]
        let primary = makePrompt(
            community: community,
            promptKey: promptKey,
            referenceDate: referenceDate,
            candidate: primaryCandidate,
            shareSafe: shareSafe
        )
        let alternates = alternatePrompts(
            for: community,
            promptKey: promptKey,
            referenceDate: referenceDate,
            excluding: primaryCandidate.text,
            shareSafe: shareSafe
        )
        return CommunityPromptBundle(primary: primary, alternates: alternates)
    }

    public func previewPrompts(
        for community: CommunityTemplate,
        startDate: Date,
        count: Int
    ) -> [CommunityPrompt] {
        guard count > 0 else { return [] }

        return (0..<count).compactMap { offset in
            let nextDate: Date
            switch community.promptSchedule {
            case .daily:
                nextDate = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            case .weekly:
                nextDate = calendar.date(byAdding: .weekOfYear, value: offset, to: startDate) ?? startDate
            }
            return promptBundle(for: community, referenceDate: nextDate).primary
        }
    }

    private func alternatePrompts(
        for community: CommunityTemplate,
        promptKey: String,
        referenceDate: Date,
        excluding primaryText: String,
        shareSafe: Bool
    ) -> [CommunityPrompt] {
        let pool = promptPool(for: community).all
        var used = Set([primaryText])
        var alternates: [CommunityPrompt] = []

        for offset in 1...8 {
            let index = stableIndex(
                seed: "\(community.id)|\(promptKey)|alt|\(offset)",
                count: pool.count
            )
            let candidate = pool[index]
            guard !used.contains(candidate.text) else { continue }
            used.insert(candidate.text)
            alternates.append(
                makePrompt(
                    community: community,
                    promptKey: promptKey,
                    referenceDate: referenceDate,
                    candidate: candidate,
                    shareSafe: shareSafe
                )
            )
            if alternates.count >= 3 {
                break
            }
        }

        return alternates
    }

    private func makePrompt(
        community: CommunityTemplate,
        promptKey: String,
        referenceDate: Date,
        candidate: PromptCandidate,
        shareSafe: Bool
    ) -> CommunityPrompt {
        let dateKey: String?
        let weekKey: String?
        switch community.promptSchedule {
        case .daily:
            dateKey = promptKey
            weekKey = nil
        case .weekly:
            dateKey = nil
            weekKey = promptKey
        }

        return CommunityPrompt(
            id: "\(community.id)|\(promptKey)|\(stableHash64(candidate.text))",
            communityId: community.id,
            text: candidate.text,
            category: community.category,
            tags: candidate.tags,
            dateKey: dateKey,
            weekKey: weekKey,
            shareSafe: shareSafe,
            createdBy: candidate.createdBy,
            isActive: true,
            answerStyle: community.promptPolicy.answerStyle
        )
    }

    private func sanitizedPinnedPrompt(for community: CommunityTemplate) -> String? {
        guard let raw = community.pinnedNextPromptText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        return isBlocked(raw, blockedWords: community.blockedWords) ? nil : String(raw.prefix(70))
    }

    private func promptPool(for community: CommunityTemplate) -> PromptPool {
        let categoryPrompts = categoryPromptCandidates(for: community.category)
        let tagPrompts = tagPromptCandidates(tags: community.allowedTags, category: community.category)
        let packPrompts = promptPackCandidates(packIDs: resolvedPromptPackIDs(for: community), category: community.category)
        let creatorPrompts = community.customPromptSeeds.map {
            PromptCandidate(text: $0, tags: community.allowedTags, createdBy: .creator)
        }

        let merged = deduplicateCandidates(
            creatorPrompts + tagPrompts + packPrompts + categoryPrompts,
            blockedWords: community.blockedWords
        )

        let fallback = PromptCandidate(
            text: fallbackPrompt(for: community.category),
            tags: community.allowedTags,
            createdBy: .system
        )

        let all = merged.isEmpty ? [fallback] : merged
        let focused = deduplicateCandidates(
            creatorPrompts + tagPrompts + packPrompts,
            blockedWords: community.blockedWords
        )

        return PromptPool(
            focused: focused,
            all: all
        )
    }

    private func categoryPromptCandidates(for category: CommunityCategory) -> [PromptCandidate] {
        switch category {
        case .games:
            return Self.gameBasePrompts.map { .init(text: $0, tags: ["games"], createdBy: .system) }
        case .study:
            return [
                "今週いちばん集中できた勉強は？",
                "今日の学びをひとことで残すなら？",
                "次に理解したいテーマは？",
                "最近ちょっと前進した勉強習慣は？"
            ].map { .init(text: $0, tags: ["study"], createdBy: .system) }
        case .music:
            return [
                "今の気分に合う一曲は？",
                "今週いちばん聴いた音は？",
                "最近また聴き返したくなった曲は？",
                "今の自分を表すプレイリスト名は？"
            ].map { .init(text: $0, tags: ["music"], createdBy: .system) }
        case .anime:
            return [
                "最近心に残ったシーンは？",
                "推しキャラを一言で表すなら？",
                "今また観返したい作品は？",
                "今週語りたいアニメの魅力は？"
            ].map { .init(text: $0, tags: ["anime"], createdBy: .system) }
        case .books:
            return [
                "最近読み返したい一冊は？",
                "本の中で今も残っている言葉は？",
                "今日の気分に合う本の雰囲気は？",
                "誰かにすすめたい一冊は？"
            ].map { .init(text: $0, tags: ["books"], createdBy: .system) }
        case .fitness:
            return [
                "今週の小さな達成をひとことで残すなら？",
                "今日いちばん心地よかった動きは？",
                "次に続けたい健康習慣は？",
                "最近の自分に合う運動ペースは？"
            ].map { .init(text: $0, tags: ["fitness"], createdBy: .system) }
        case .dailyLife:
            return [
                "今日の気分を一言で残すなら？",
                "最近ちょっと嬉しかったことは？",
                "今週の小さな景色をひとつ挙げるなら？",
                "明日の自分に渡したい一言は？"
            ].map { .init(text: $0, tags: ["daily"], createdBy: .system) }
        case .custom:
            return [
                "この部屋らしい一言を残すなら？",
                "今週いちばん話したいテーマは？",
                "今日の気分をこの部屋の言葉で表すなら？",
                "最近の自分をひとことで残すなら？"
            ].map { .init(text: $0, tags: ["custom"], createdBy: .system) }
        }
    }

    private func tagPromptCandidates(
        tags: [String],
        category: CommunityCategory
    ) -> [PromptCandidate] {
        guard category == .games else { return [] }

        let normalizedTags = Set(tags.map { $0.lowercased() })
        var prompts: [PromptCandidate] = []

        for tag in normalizedTags.sorted() {
            let texts = Self.gameTagPrompts[tag] ?? []
            prompts.append(contentsOf: texts.map { text in
                PromptCandidate(text: text, tags: ["games", tag], createdBy: .localGenerated)
            })
        }

        return prompts
    }

    private func promptPackCandidates(
        packIDs: [String],
        category: CommunityCategory
    ) -> [PromptCandidate] {
        guard category == .games else { return [] }

        var prompts: [PromptCandidate] = []
        for packID in packIDs {
            let texts = Self.gamePromptPacks[packID] ?? []
            prompts.append(contentsOf: texts.map { text in
                PromptCandidate(text: text, tags: ["games", packID], createdBy: .localGenerated)
            })
        }
        return prompts
    }

    private func resolvedPromptPackIDs(for community: CommunityTemplate) -> [String] {
        var ids = community.promptPacks
        if let themeDecorationId = community.themeDecorationId,
           let item = CardDecorationCatalog.item(for: themeDecorationId),
           item.itemType == .promptPack {
            ids.append(themeDecorationId.lowercased())
        }
        return Array(Set(ids.map { $0.lowercased() })).sorted()
    }

    private func deduplicateCandidates(
        _ candidates: [PromptCandidate],
        blockedWords: [String]
    ) -> [PromptCandidate] {
        var seen = Set<String>()
        var result: [PromptCandidate] = []

        for candidate in candidates {
            let text = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard !isBlocked(text, blockedWords: blockedWords) else { continue }
            guard !seen.contains(text) else { continue }
            seen.insert(text)
            result.append(
                PromptCandidate(
                    text: String(text.prefix(70)),
                    tags: Array(Set(candidate.tags.map { $0.lowercased() })).sorted(),
                    createdBy: candidate.createdBy
                )
            )
        }

        return result
    }

    private func isBlocked(_ text: String, blockedWords: [String]) -> Bool {
        let lowercased = text.lowercased()
        return blockedWords.contains { blocked in
            let trimmed = blocked.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return false }
            return lowercased.contains(trimmed)
        }
    }

    private func makePromptKey(for community: CommunityTemplate, referenceDate: Date) -> String {
        switch community.promptSchedule {
        case .daily:
            return DateKey.key(of: referenceDate, calendar: calendar)
        case .weekly:
            return weekKey(for: referenceDate)
        }
    }

    private func weekKey(for date: Date) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private func stableIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(stableHash64(seed) % UInt64(count))
    }

    private func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func fallbackPrompt(for category: CommunityCategory) -> String {
        switch category {
        case .games:
            return "最近いちばん時間を忘れたゲームは？"
        case .study:
            return "今日の学びをひとことで残すなら？"
        case .music:
            return "今の気分に合う一曲は？"
        case .anime:
            return "今週語りたい作品は？"
        case .books:
            return "最近読み返したい一冊は？"
        case .fitness:
            return "今週の小さな達成をひとことで残すなら？"
        case .dailyLife:
            return "今日の気分を一言で残すなら？"
        case .custom:
            return "この部屋らしい一言を残すなら？"
        }
    }

    private struct PromptPool {
        let focused: [PromptCandidate]
        let all: [PromptCandidate]
    }

    private struct PromptCandidate {
        let text: String
        let tags: [String]
        let createdBy: CommunityPromptCreatedBy
    }

    private static let gameBasePrompts: [String] = [
        "最近いちばん時間を忘れたゲームは？",
        "今週いちばん触ったゲームは？",
        "最近また遊びたくなったゲームは？",
        "今日のゲーム気分を一言で。",
        "初めてハマったゲームは？",
        "子どもの頃の思い出のゲームは？",
        "ゲームで泣いた経験は？",
        "忘れられないラスボス戦は？",
        "友達にすすめたいゲームは？",
        "もっと評価されるべきゲームは？",
        "初心者にすすめたい一本は？",
        "今年やってよかったゲームは？",
        "推しキャラについて一言。",
        "住んでみたいゲームの世界は？",
        "好きな街・村・拠点は？",
        "自分が仲間にしたいキャラは？",
        "今週クリアしたいゲームは？",
        "積みゲーを1本選ぶなら？",
        "今日10分だけ進めたいゲームは？",
        "次に挑戦したいジャンルは？",
        "自分にとっての神ゲーは？",
        "好きなゲームBGMは？",
        "好きな戦闘システムは？",
        "好きなゲームの雰囲気は？",
        "誰かと一緒に遊びたいゲームは？",
        "友達と盛り上がったゲームは？",
        "配信で見たいゲームは？",
        "語り合いたいゲームは？",
        "ゲームから学んだことは？",
        "最近のゲーム時間は満足？",
        "ゲームと生活のちょうどいい距離感は？",
        "今の自分に合うゲームは？"
    ]

    private static let gameTagPrompts: [String: [String]] = [
        "rpg": [
            "今週いちばん気になっているRPGは？",
            "好きなパーティ編成を一言で。",
            "旅をしてみたいRPGの世界は？",
            "最近また触りたいRPGの一本は？"
        ],
        "fps": [
            "最近いちばん気持ちよかったクラッチは？",
            "好きな武器タイプを一言で。",
            "今週見直したい立ち回りは？",
            "対戦前に上げたい気分を表すなら？"
        ],
        "nintendo": [
            "任天堂タイトルで今また遊びたい一本は？",
            "好きな任天堂キャラを一言で語るなら？",
            "家族や友達と遊びたい任天堂ゲームは？",
            "いちばん思い出に残っている任天堂ハードは？"
        ],
        "indie": [
            "もっと広まってほしいインディーゲームは？",
            "インディーゲームで心を掴まれた瞬間は？",
            "今週気になっている小さな一本は？",
            "雰囲気で惹かれたインディー作品は？"
        ],
        "retro": [
            "今でも通じるレトロゲームの魅力は？",
            "思い出のドット絵ゲームは？",
            "レトロゲームの好きな音を挙げるなら？",
            "今遊んでも熱い昔の一本は？"
        ],
        "character": [
            "推しキャラを一言で表すなら？",
            "今いちばん語りたい主人公は？",
            "仲間にしたいサブキャラは？",
            "世界観ごと好きなキャラは？"
        ],
        "backlog": [
            "今週崩したい積みゲーは？",
            "積みゲーを開くハードルを下げる一言は？",
            "最初に再開したい途中セーブは？",
            "積みゲーの中で今の気分に合う一本は？"
        ],
        "competitive": [
            "今週の対戦反省を一言で残すなら？",
            "勝ち筋が見えた試合は？",
            "次に鍛えたい判断は？",
            "悔しかった場面から学べたことは？"
        ],
        "musicgame": [
            "今の気分で叩きたい一曲は？",
            "好きな譜面のタイプは？",
            "最近更新したいスコアは？",
            "音ゲーで上がる瞬間を一言で。"
        ]
    ]

    private static let gamePromptPacks: [String: [String]] = [
        "retro": [
            "ドット絵で思い出すゲームは？",
            "レトロゲームのUIで好きなものは？",
            "昔のゲーム雑誌で覚えている一本は？"
        ],
        "arcade": [
            "ゲームセンターで思い出す一台は？",
            "スコアアタックしたくなるゲームは？",
            "アーケード気分で遊びたい一本は？"
        ],
        "matrix": [
            "攻略を考えるのが楽しいゲームは？",
            "今週の最適解を探したいゲームは？",
            "頭を使って前進したい一本は？"
        ]
    ]
}
