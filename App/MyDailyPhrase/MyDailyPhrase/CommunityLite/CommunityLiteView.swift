import SwiftUI
import UIKit
import Combine
import Domain
import Presentation

@MainActor
final class CommunityLiteViewModel: ObservableObject {
    @Published private(set) var displayName: String = "Me"
    @Published private(set) var userId: String = ""
    @Published private(set) var selectedDecorationId: String = CardDecorationCatalog.classicId
    @Published private(set) var streak: Int = 0
    @Published private(set) var weeklyChallenge: CommunityLiteWeeklyChallenge
    @Published private(set) var inviteURL: URL? = nil
    @Published private(set) var inviteShareText: String = ""
    @Published private(set) var ownedDecorationItems: [CardDecoration] = []
    @Published private(set) var creatorEntitlement: CreatorEntitlementState = CreatorEntitlementState(
        hasCreatorPass: false,
        canCreateCommunity: false,
        entitlementSource: .none
    )
    @Published private(set) var communities: [CommunityTemplate] = []
    @Published private(set) var currentCommunityPromptBundle: CommunityPromptBundle? = nil
    @Published private(set) var currentCommunityResponse: CommunityResponse? = nil
    @Published private(set) var currentCommunityPreviewWindow: [CommunityPrompt] = []

    @Published var weeklyResponse: String = "" {
        didSet { persistUIState() }
    }
    @Published var includeWeeklyResponseInShare: Bool = false {
        didSet { persistUIState() }
    }
    @Published var includeStreakInProfileShare: Bool = true {
        didSet { persistUIState() }
    }
    @Published var selectedReaction: CommunityLiteReactionStamp = .sparkles {
        didSet { persistUIState() }
    }
    @Published var selectedCommunityId: String? = nil {
        didSet {
            defaults.set(selectedCommunityId, forKey: selectedCommunityIdKey)
            refreshSelectedCommunityContext()
        }
    }
    @Published var communityAnswerDraft: String = ""
    @Published var includeCommunityAnswerInShare: Bool = false {
        didSet { persistUIState() }
    }

    @Published var draftName: String = ""
    @Published var draftDescription: String = ""
    @Published var draftCategory: CommunityCategory = .games
    @Published var draftEmoji: String = CommunityTemplate.defaultEmoji(for: .games)
    @Published var draftTone: CommunityPromptPolicy.Tone = .fun
    @Published var draftPromptLength: CommunityPromptPolicy.PromptLength = .short
    @Published var draftPrivacyLevel: CommunityPromptPolicy.PrivacyLevel = .safeToShare
    @Published var draftAnswerStyle: CommunityPromptPolicy.AnswerStyle = .onePhrase
    @Published var draftSchedule: CommunityPromptSchedule = .daily
    @Published var draftTagsText: String = "games"
    @Published var draftBlockedWordsText: String = ""
    @Published var draftCustomPromptSeedsText: String = ""
    @Published var draftPinnedPromptText: String = ""
    @Published var draftThemeDecorationId: String? = nil
    @Published var lastMessage: String? = nil

    private let getMyProfile: GetMyProfileUseCase
    private let computeStreak: ComputeStreakUseCase
    private let listCommunities: ListCommunitiesUseCase
    private let saveCommunityTemplate: SaveCommunityTemplateUseCase
    private let joinCommunity: JoinCommunityUseCase
    private let leaveCommunity: LeaveCommunityUseCase
    private let getCommunityResponse: GetCommunityResponseUseCase
    private let saveCommunityResponse: SaveCommunityResponseUseCase
    private let defaults: UserDefaults
    private let timeZone: TimeZone
    private let creatorEntitlementService: CreatorEntitlementService
    private let calendar: Calendar
    private let promptEngine: CommunityPromptEngine

    private var referenceDate: Date = Date()

    init(
        getMyProfile: GetMyProfileUseCase,
        computeStreak: ComputeStreakUseCase,
        listCommunities: ListCommunitiesUseCase,
        saveCommunityTemplate: SaveCommunityTemplateUseCase,
        joinCommunity: JoinCommunityUseCase,
        leaveCommunity: LeaveCommunityUseCase,
        getCommunityResponse: GetCommunityResponseUseCase,
        saveCommunityResponse: SaveCommunityResponseUseCase,
        defaults: UserDefaults,
        timeZone: TimeZone,
        creatorEntitlementService: CreatorEntitlementService
    ) {
        self.getMyProfile = getMyProfile
        self.computeStreak = computeStreak
        self.listCommunities = listCommunities
        self.saveCommunityTemplate = saveCommunityTemplate
        self.joinCommunity = joinCommunity
        self.leaveCommunity = leaveCommunity
        self.getCommunityResponse = getCommunityResponse
        self.saveCommunityResponse = saveCommunityResponse
        self.defaults = defaults
        self.timeZone = timeZone
        self.creatorEntitlementService = creatorEntitlementService

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        self.calendar = calendar
        self.promptEngine = CommunityPromptEngine(calendar: calendar)
        self.weeklyChallenge = CommunityLiteSupport.challenge(for: Date(), calendar: calendar)
    }

    var equippedItem: CardDecoration {
        CardDecorationCatalog.byId(selectedDecorationId)
            ?? CardDecoration(id: CardDecorationCatalog.classicId, name: "Classic", rarity: .common, weight: 0)
    }

    var equippedTitle: String? {
        GachaThemePresentation.profileTitle(for: equippedItem)
    }

    var socialHeaderText: String {
        "公開フィードはまだありません。参加は無料、作成は将来のCreator Pass前提で、安心な共有だけを先に育てる準備版です。"
    }

    var joinedCommunities: [CommunityTemplate] {
        communities.filter(\.isJoined)
    }

    var availableCommunities: [CommunityTemplate] {
        communities.filter { $0.category == .games || !$0.isOfficialPreset || FeatureFlags.gameCommunityEnabled }
    }

    var selectedCommunity: CommunityTemplate? {
        guard let selectedCommunityId else { return nil }
        return communities.first { $0.id == selectedCommunityId }
    }

    var selectedCommunityDecorationId: String {
        selectedCommunity?.themeDecorationId ?? selectedDecorationId
    }

    var draftTags: [String] {
        tokenize(draftTagsText)
    }

    var draftBlockedWords: [String] {
        tokenize(draftBlockedWordsText)
    }

    var draftCustomPromptSeeds: [String] {
        draftCustomPromptSeedsText
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var canCreateCommunity: Bool {
        creatorEntitlement.canCreateCommunity
    }

    var communityCreationStatusText: String {
        if creatorEntitlement.canCreateCommunity {
            return "Creator Passの権利が有効です。この端末ではローカルな招待制コミュニティを作成できます。"
        }
        return "参加は無料です。コミュニティ作成はCreator Pass向け機能として準備中です。"
    }

    var selectedCommunityPromptLabel: String {
        switch selectedCommunity?.promptSchedule ?? .daily {
        case .daily:
            return "今日のお題"
        case .weekly:
            return "今週のお題"
        }
    }

    var draftCommunityPreview: CommunityTemplate {
        var template = CommunityTemplate(
            id: "draft.\(stableDraftSeed)",
            name: draftName,
            description: draftDescription,
            category: draftCategory,
            emoji: draftEmoji,
            createdAt: referenceDate,
            creatorDisplayName: displayName,
            creatorId: userId,
            visibility: .inviteOnly,
            promptPolicy: CommunityPromptPolicy(
                tone: draftTone,
                promptLength: draftPromptLength,
                privacyLevel: draftPrivacyLevel,
                answerStyle: draftAnswerStyle
            ),
            promptSchedule: draftSchedule,
            promptPacks: selectedPromptPacksForDraft(),
            themeDecorationId: draftThemeDecorationId ?? selectedDecorationId,
            allowedTags: draftTags,
            blockedWords: draftBlockedWords,
            isOfficialPreset: false,
            requiresCreatorPassToCreate: true,
            isJoined: false,
            customPromptSeeds: draftCustomPromptSeeds,
            pinnedNextPromptText: draftPinnedPromptText
        )
        template.normalize()
        return template
    }

    var draftPromptBundle: CommunityPromptBundle {
        promptEngine.promptBundle(for: draftCommunityPreview, referenceDate: referenceDate)
    }

    var draftPromptPreviewWindow: [CommunityPrompt] {
        let count = draftCommunityPreview.promptSchedule == .daily ? 7 : 4
        return promptEngine.previewPrompts(for: draftCommunityPreview, startDate: referenceDate, count: count)
    }

    func load(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
        refreshCreatorEntitlement()

        let profile = getMyProfile()
        displayName = profile.displayName
        userId = profile.userId
        selectedDecorationId = profile.selectedDecorationId
        streak = computeStreak.execute()
        ownedDecorationItems = profile.ownedDecorationIds
            .compactMap(CardDecorationCatalog.byId)
            .sorted { lhs, rhs in
                if lhs.rarity.rank != rhs.rarity.rank {
                    return lhs.rarity.rank > rhs.rarity.rank
                }
                return lhs.name < rhs.name
            }
        if draftThemeDecorationId == nil {
            draftThemeDecorationId = selectedDecorationId
        }

        weeklyChallenge = CommunityLiteSupport.challenge(for: referenceDate, calendar: calendar)

        let referralCode = ReferralProgram.referralCode(for: profile.userId)
        inviteURL = ReferralProgram.inviteURL(
            inviterId: profile.userId,
            inviterName: profile.displayName,
            code: referralCode
        )
        inviteShareText = [
            "ひとこと日記 招待コード: \(referralCode)",
            "外部共有でつながろう。公開フィードは使わず、必要なときだけ共有できます。",
            "#ひとこと日記"
        ].joined(separator: "\n")

        restoreUIState()
        bootstrapOfficialCommunities()
        reloadCommunities()
        ensureSelectedCommunity()
        refreshSelectedCommunityContext()
    }

    func joinSelectedCommunity() {
        guard let selectedCommunity else { return }
        join(communityId: selectedCommunity.id)
    }

    func join(communityId: String) {
        joinCommunity(communityId: communityId)
        reloadCommunities()
        if selectedCommunityId != communityId {
            selectedCommunityId = communityId
        } else {
            refreshSelectedCommunityContext()
        }
        lastMessage = "無料でコミュニティに参加しました"
    }

    func leaveSelectedCommunity() {
        guard let selectedCommunity else { return }
        leave(communityId: selectedCommunity.id)
    }

    func leave(communityId: String) {
        leaveCommunity(communityId: communityId)
        reloadCommunities()
        ensureSelectedCommunity()
        refreshSelectedCommunityContext()
        lastMessage = "コミュニティから離れました"
    }

    func saveSelectedCommunityResponse() {
        guard let selectedCommunity,
              let prompt = currentCommunityPromptBundle?.primary else {
            return
        }

        let trimmed = communityAnswerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastMessage = "回答が空のため保存されませんでした"
            return
        }

        let saved = saveCommunityResponse(
            CommunityResponse(
                communityId: selectedCommunity.id,
                promptKey: prompt.promptKey,
                promptText: prompt.text,
                answer: trimmed,
                updatedAt: Date()
            )
        )
        currentCommunityResponse = saved
        communityAnswerDraft = saved.answer
        lastMessage = "コミュニティの回答を保存しました"
    }

    func createCommunity() {
        guard creatorEntitlement.canCreateCommunity else {
            lastMessage = "参加は無料です。コミュニティ作成はCreator Pass向け機能として準備中です。"
            return
        }

        var community = draftCommunityPreview
        community.id = "creator.\(UUID().uuidString)"
        community.createdAt = Date()
        community.creatorDisplayName = displayName
        community.creatorId = userId
        community.isJoined = true
        community.joinedAt = Date()
        community.requiresCreatorPassToCreate = true
        community.isOfficialPreset = false

        let saved = saveCommunityTemplate(community)
        joinCommunity(communityId: saved.id)
        reloadCommunities()
        selectedCommunityId = saved.id
        lastMessage = "ローカルな招待制コミュニティを作成しました"
    }

    fileprivate func applyGamePreset(_ preset: GameCommunityPreset) {
        draftName = preset.name
        draftDescription = preset.description
        draftCategory = .games
        draftEmoji = preset.emoji
        draftTone = preset.tone
        draftPromptLength = preset.promptLength
        draftPrivacyLevel = preset.privacyLevel
        draftAnswerStyle = preset.answerStyle
        draftSchedule = preset.schedule
        draftTagsText = preset.tags.joined(separator: ", ")
    }

    func communityPromptShareText(includeAnswer: Bool) -> String? {
        guard let community = selectedCommunity,
              let prompt = currentCommunityPromptBundle?.primary else {
            return nil
        }

        return CommunityLiteSupport.communityPromptShareText(
            community: community,
            prompt: prompt,
            answer: communityAnswerDraft,
            includeAnswer: includeAnswer,
            reaction: selectedReaction
        )
    }

    func joinedCommunityShareText() -> String? {
        guard let community = selectedCommunity else { return nil }
        return CommunityLiteSupport.joinedCommunityShareText(community: community)
    }

    func weeklyChallengeShareText() -> String {
        CommunityLiteSupport.weeklyChallengeShareText(
            challenge: weeklyChallenge,
            displayName: displayName,
            profileTitle: equippedTitle,
            reaction: selectedReaction,
            answer: weeklyResponse,
            includeAnswer: includeWeeklyResponseInShare
        )
    }

    func profileShareText() -> String {
        CommunityLiteSupport.profileCardShareText(
            displayName: displayName,
            profileTitle: equippedTitle,
            streak: streak,
            reaction: selectedReaction,
            includeStreak: includeStreakInProfileShare
        )
    }

    func achievementShareText() -> String {
        CommunityLiteSupport.achievementShareText(
            displayName: displayName,
            streak: streak,
            profileTitle: equippedTitle,
            reaction: selectedReaction
        )
    }

    #if DEBUG
    var debugCreatorOverrideEnabled: Bool {
        creatorEntitlementService.isDebugOverrideEnabled()
    }

    func toggleDebugCreatorOverride() {
        creatorEntitlementService.setDebugOverrideEnabled(!debugCreatorOverrideEnabled)
        refreshCreatorEntitlement()
    }
    #endif

    private func refreshCreatorEntitlement() {
        creatorEntitlement = creatorEntitlementService.currentState()
    }

    private func selectedPromptPreviewCount(for community: CommunityTemplate) -> Int {
        community.promptSchedule == .daily ? 7 : 4
    }

    private func ensureSelectedCommunity() {
        if let selectedCommunityId,
           communities.contains(where: { $0.id == selectedCommunityId }) {
            return
        }

        if let joined = joinedCommunities.first {
            selectedCommunityId = joined.id
        } else {
            selectedCommunityId = communities.first?.id
        }
    }

    private func refreshSelectedCommunityContext() {
        guard let selectedCommunity else {
            currentCommunityPromptBundle = nil
            currentCommunityPreviewWindow = []
            currentCommunityResponse = nil
            communityAnswerDraft = ""
            return
        }

        let bundle = promptEngine.promptBundle(for: selectedCommunity, referenceDate: referenceDate)
        currentCommunityPromptBundle = bundle
        currentCommunityPreviewWindow = promptEngine.previewPrompts(
            for: selectedCommunity,
            startDate: referenceDate,
            count: selectedPromptPreviewCount(for: selectedCommunity)
        )
        let response = getCommunityResponse(
            communityId: selectedCommunity.id,
            promptKey: bundle.primary.promptKey
        )
        currentCommunityResponse = response
        communityAnswerDraft = response?.answer ?? ""
    }

    private func bootstrapOfficialCommunities() {
        guard FeatureFlags.gameCommunityEnabled else { return }

        let existing = Dictionary(uniqueKeysWithValues: listCommunities().map { ($0.id, $0) })
        for preset in CommunityLiteSupport.officialPresetCommunities() {
            var merged = preset
            if let saved = existing[preset.id] {
                merged.isJoined = saved.isJoined
                merged.joinedAt = saved.joinedAt
                merged.customPromptSeeds = saved.customPromptSeeds
                merged.pinnedNextPromptText = saved.pinnedNextPromptText
            }
            _ = saveCommunityTemplate(merged)
        }
    }

    private func reloadCommunities() {
        communities = listCommunities()
            .sorted { lhs, rhs in
                if lhs.isJoined != rhs.isJoined {
                    return lhs.isJoined && !rhs.isJoined
                }
                if lhs.isOfficialPreset != rhs.isOfficialPreset {
                    return lhs.isOfficialPreset && !rhs.isOfficialPreset
                }
                if lhs.category != rhs.category {
                    return lhs.category.rawValue < rhs.category.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    private func persistUIState() {
        defaults.set(weeklyResponse, forKey: weeklyDraftKey)
        defaults.set(includeWeeklyResponseInShare, forKey: includeWeeklyAnswerKey)
        defaults.set(includeStreakInProfileShare, forKey: includeStreakKey)
        defaults.set(includeCommunityAnswerInShare, forKey: includeCommunityAnswerKey)
        defaults.set(selectedReaction.rawValue, forKey: reactionKey)
    }

    private func restoreUIState() {
        weeklyResponse = defaults.string(forKey: weeklyDraftKey) ?? ""
        includeWeeklyResponseInShare = defaults.object(forKey: includeWeeklyAnswerKey) as? Bool ?? false
        includeStreakInProfileShare = defaults.object(forKey: includeStreakKey) as? Bool ?? true
        includeCommunityAnswerInShare = defaults.object(forKey: includeCommunityAnswerKey) as? Bool ?? false
        if let reaction = defaults.string(forKey: reactionKey),
           let stamp = CommunityLiteReactionStamp(rawValue: reaction) {
            selectedReaction = stamp
        } else {
            selectedReaction = .sparkles
        }
        selectedCommunityId = defaults.string(forKey: selectedCommunityIdKey)
    }

    private var weeklyDraftKey: String {
        "MyDailyPhrase.communityLite.weeklyDraft.\(weeklyChallenge.weekKey)"
    }

    private let includeWeeklyAnswerKey = "MyDailyPhrase.communityLite.includeWeeklyAnswer.v2"
    private let includeStreakKey = "MyDailyPhrase.communityLite.includeStreak.v2"
    private let includeCommunityAnswerKey = "MyDailyPhrase.communityLite.includeCommunityAnswer.v1"
    private let reactionKey = "MyDailyPhrase.communityLite.reaction.v2"
    private let selectedCommunityIdKey = "MyDailyPhrase.communityLite.selectedCommunityId.v1"

    private var stableDraftSeed: String {
        [draftName, draftDescription, draftTagsText, draftEmoji].joined(separator: "|")
    }

    private func tokenize(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "," || $0 == "、" || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func selectedPromptPacksForDraft() -> [String] {
        guard let draftThemeDecorationId,
              let item = CardDecorationCatalog.item(for: draftThemeDecorationId),
              item.itemType == .promptPack else {
            return []
        }
        return [draftThemeDecorationId]
    }
}

private struct GameCommunityPreset: Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let tags: [String]
    let tone: CommunityPromptPolicy.Tone
    let promptLength: CommunityPromptPolicy.PromptLength
    let privacyLevel: CommunityPromptPolicy.PrivacyLevel
    let answerStyle: CommunityPromptPolicy.AnswerStyle
    let schedule: CommunityPromptSchedule

    init(
        id: String,
        name: String,
        description: String,
        emoji: String,
        tags: [String],
        tone: CommunityPromptPolicy.Tone,
        promptLength: CommunityPromptPolicy.PromptLength = .short,
        privacyLevel: CommunityPromptPolicy.PrivacyLevel = .safeToShare,
        answerStyle: CommunityPromptPolicy.AnswerStyle = .onePhrase,
        schedule: CommunityPromptSchedule = .daily
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.tags = tags
        self.tone = tone
        self.promptLength = promptLength
        self.privacyLevel = privacyLevel
        self.answerStyle = answerStyle
        self.schedule = schedule
    }
}

fileprivate extension CommunityLiteViewModel {
    var gameCreationPresets: [GameCommunityPreset] {
        [
            GameCommunityPreset(id: "games.general", name: "ゲーム好きの部屋", description: "最近遊んだ一本や推しキャラを気軽に残す定番ルームです。", emoji: "🎮", tags: ["games", "general"], tone: .casual),
            GameCommunityPreset(id: "games.rpg", name: "RPG好きの部屋", description: "旅や仲間、世界観について深めに語れるRPG向けルームです。", emoji: "🗺️", tags: ["games", "rpg", "story"], tone: .deep, promptLength: .medium, answerStyle: .shortMemo, schedule: .weekly),
            GameCommunityPreset(id: "games.fps", name: "FPS好きの部屋", description: "クラッチや反省を短く残せる対戦寄りの部屋です。", emoji: "🎯", tags: ["games", "fps", "competitive"], tone: .challenge, answerStyle: .ranking),
            GameCommunityPreset(id: "games.nintendo", name: "任天堂好きの部屋", description: "思い出や好きなキャラを明るく話せる部屋です。", emoji: "🍄", tags: ["games", "nintendo"], tone: .nostalgic, schedule: .weekly),
            GameCommunityPreset(id: "games.indie", name: "インディーゲーム好きの部屋", description: "小さな傑作や雰囲気ゲーを静かに語れる部屋です。", emoji: "🌙", tags: ["games", "indie"], tone: .deep, promptLength: .medium, answerStyle: .recommendation, schedule: .weekly),
            GameCommunityPreset(id: "games.backlog", name: "積みゲー消化部", description: "今週ひらきたい一本をゆるく宣言して続ける部屋です。", emoji: "📦", tags: ["games", "backlog"], tone: .challenge),
            GameCommunityPreset(id: "games.retro", name: "レトロゲーム部", description: "昔のハードやドット絵の思い出を残す部屋です。", emoji: "🕹️", tags: ["games", "retro"], tone: .nostalgic, answerStyle: .shortMemo, schedule: .weekly),
            GameCommunityPreset(id: "games.character", name: "推しキャラ語り部", description: "好きなキャラや世界観を一言で残せる部屋です。", emoji: "💫", tags: ["games", "character"], tone: .fun),
            GameCommunityPreset(id: "games.musicgame", name: "音ゲー部", description: "譜面、スコア、好きな一曲を軽やかに残す部屋です。", emoji: "🎼", tags: ["games", "musicgame"], tone: .fun, answerStyle: .ranking),
            GameCommunityPreset(id: "games.competitive", name: "対戦ゲーム反省会", description: "勝ち筋や反省を落ち着いて振り返る部屋です。", emoji: "🔥", tags: ["games", "competitive", "fps"], tone: .challenge, promptLength: .medium, privacyLevel: .privateReflection, answerStyle: .shortMemo, schedule: .weekly)
        ]
    }
}

struct CommunityLiteView: View {
    @ObservedObject var vm: CommunityLiteViewModel

    @State private var shareSheetItems: [Any] = []
    @State private var isPresentingShareSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                heroCard
                communitySection
                weeklyChallengeSection
                creatorSection
                profileExchangeSection
                streakSection
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(AppScreenBackground())
        .navigationTitle("みんな")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            vm.load()
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
    }

    private var heroCard: some View {
        Card("みんなの部屋", decorationId: vm.selectedDecorationId) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ゲームや好きなテーマの部屋に無料で参加して、お題にひとこと答えられます。公開フィードなしで、安心して使える共有だけを先に楽しめます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        InfoBadge(title: "参加は無料", systemImage: "person.badge.plus", tint: .green)
                        PremiumBadge(title: "作成はCreator Pass")
                        InfoBadge(title: "公開コメントなし", systemImage: "shield", tint: .indigo)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "参加は無料", systemImage: "person.badge.plus", tint: .green)
                        PremiumBadge(title: "作成はCreator Pass")
                        InfoBadge(title: "公開コメントなし", systemImage: "shield", tint: .indigo)
                    }
                }

                if !vm.communityCreationStatusText.isEmpty {
                    Text(vm.communityCreationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weeklyChallengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "みんなのチャレンジ",
                subtitle: "部屋に入っていなくても、今週のお題をローカルで書いて共有できます。"
            )

            CommunityLiteSharePreviewCard(
                model: weeklyChallengeModel(includeAnswer: vm.includeWeeklyResponseInShare)
            )

            Card("今週のお題", decorationId: vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.weeklyChallenge.title)
                                .font(.headline)
                            Text(vm.weeklyChallenge.weekKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(vm.weeklyChallenge.badgeTitle)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    Text(vm.weeklyChallenge.prompt)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    editorCard(
                        text: $vm.weeklyResponse,
                        placeholder: "共有したいときだけ、ひとことをここに書けます。"
                    )

                    Toggle("回答も共有カードに入れる", isOn: $vm.includeWeeklyResponseInShare)
                        .font(.subheadline)

                    Text("初期状態では回答は共有されません。外部に出すのは明示的にONにしたときだけです。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            reactionPicker

            actionButtons(
                primaryTitle: "チャレンジカードを共有",
                primarySystemImage: "square.and.arrow.up",
                primaryAction: { shareWeeklyChallengeCard() },
                secondaryTitle: "あとで書く",
                secondarySystemImage: "bookmark",
                secondaryAction: { vm.lastMessage = "下書きを保存しました" }
            )
        }
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "コミュニティ",
                subtitle: "参加は無料です。ゲーム系の公式プリセットから、自分に合う部屋を見つけられます。"
            )

            if !vm.joinedCommunities.isEmpty {
                joinedCommunitiesStrip
            } else {
                EmptyStateCard(
                    title: "まだ参加している部屋はありません",
                    message: "気になる部屋を1つ選ぶと、その部屋専用のお題を無料で楽しめます。",
                    systemImage: "person.2"
                )
            }

            communityCatalogGrid

            if let community = vm.selectedCommunity {
                communityDetailSection(community)
            }
        }
    }

    private var joinedCommunitiesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("参加中")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.joinedCommunities) { community in
                        Button {
                            vm.selectedCommunityId = community.id
                        } label: {
                            HStack(spacing: 8) {
                                Text(community.emoji)
                                Text(community.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(vm.selectedCommunityId == community.id ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var communityCatalogGrid: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            ForEach(vm.availableCommunities) { community in
                Button {
                    vm.selectedCommunityId = community.id
                } label: {
                    Card(nil, decorationId: community.themeDecorationId ?? vm.selectedDecorationId) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text(community.emoji)
                                    .font(.title3)
                                Spacer()
                                if community.isJoined {
                                    Text("参加中")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.16))
                                        .clipShape(Capsule())
                                } else {
                                    Text("参加無料")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(community.name)
                                .font(.headline)
                                .multilineTextAlignment(.leading)

                            Text(community.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            HStack {
                                Text(categoryLabel(community.category))
                                Spacer()
                                Text(scheduleLabel(community.promptSchedule))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(vm.selectedCommunityId == community.id ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func communityDetailSection(_ community: CommunityTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "\(community.emoji) \(community.name)",
                subtitle: community.description
            )

            CommunityLiteSharePreviewCard(
                model: communityPromptModel(for: community, includeAnswer: vm.includeCommunityAnswerInShare)
            )

            Card(vm.selectedCommunityPromptLabel, decorationId: community.themeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        labelCapsule(categoryLabel(community.category), systemImage: "square.grid.2x2")
                        labelCapsule(scheduleLabel(community.promptSchedule), systemImage: "calendar")
                        if let themeDecorationId = community.themeDecorationId,
                           let item = CardDecorationCatalog.byId(themeDecorationId) {
                            labelCapsule(item.name, systemImage: "paintpalette")
                        }
                    }

                    if let prompt = vm.currentCommunityPromptBundle?.primary {
                        Text(prompt.text)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !(vm.currentCommunityPromptBundle?.alternates ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("候補")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(vm.currentCommunityPromptBundle?.alternates ?? [], id: \.id) { alternate in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 2)
                                    Text(alternate.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            if community.isJoined {
                Card("ローカル回答", decorationId: community.themeDecorationId ?? vm.selectedDecorationId) {
                    VStack(alignment: .leading, spacing: 12) {
                        editorCard(
                            text: $vm.communityAnswerDraft,
                            placeholder: "この部屋の今日のお題に、ひとこと残せます。"
                        )

                        Toggle("回答も共有カードに含める", isOn: $vm.includeCommunityAnswerInShare)
                            .font(.subheadline)

                        Text("共有時の初期状態では回答は入りません。答えを外に出すのは明示的にONにしたときだけです。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                actionButtons(
                    primaryTitle: "回答を保存",
                    primarySystemImage: "square.and.arrow.down",
                    primaryAction: { vm.saveSelectedCommunityResponse() },
                    secondaryTitle: "部屋カードを共有",
                    secondarySystemImage: "square.and.arrow.up",
                    secondaryAction: { shareSelectedCommunityCard(includeAnswer: vm.includeCommunityAnswerInShare) }
                )

                actionButtons(
                    primaryTitle: "参加した部屋として共有",
                    primarySystemImage: "person.2",
                    primaryAction: { shareJoinedCommunityCard() },
                    secondaryTitle: "コミュニティを離れる",
                    secondarySystemImage: "rectangle.portrait.and.arrow.right",
                    secondaryAction: { vm.leaveSelectedCommunity() }
                )
            } else {
                actionButtons(
                    primaryTitle: "無料で参加",
                    primarySystemImage: "person.badge.plus",
                    primaryAction: { vm.joinSelectedCommunity() },
                    secondaryTitle: "部屋カードを共有",
                    secondarySystemImage: "square.and.arrow.up",
                    secondaryAction: { shareJoinedCommunityCard() }
                )
            }

            Card("お題プレビュー", decorationId: community.themeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(vm.currentCommunityPreviewWindow.prefix(community.promptSchedule == .daily ? 7 : 4), id: \.id) { prompt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.dateKey ?? prompt.weekKey ?? prompt.id)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(prompt.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var creatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "コミュニティを作る",
                subtitle: "参加者は無料のまま、Creator Pass で自分の部屋づくりを解放できます。"
            )

            Card("作成プレビュー", decorationId: vm.draftThemeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(vm.communityCreationStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if vm.draftCategory == .games {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ゲーム向けプリセット")
                                .font(.subheadline.weight(.semibold))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(vm.gameCreationPresets) { preset in
                                        Button {
                                            vm.applyGamePreset(preset)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(preset.emoji) \(preset.name)")
                                                    .font(.caption.weight(.semibold))
                                                Text(preset.tags.joined(separator: " / "))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    TextField("コミュニティ名", text: $vm.draftName)
                        .textFieldStyle(.roundedBorder)

                    TextField("短い説明", text: $vm.draftDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            pickerCard("カテゴリ") {
                                Picker("カテゴリ", selection: $vm.draftCategory) {
                                    ForEach(CommunityCategory.allCases, id: \.self) { category in
                                        Text(categoryLabel(category)).tag(category)
                                    }
                                }
                            }
                            pickerCard("頻度") {
                                Picker("頻度", selection: $vm.draftSchedule) {
                                    ForEach(CommunityPromptSchedule.allCases, id: \.self) { schedule in
                                        Text(scheduleLabel(schedule)).tag(schedule)
                                    }
                                }
                            }
                            pickerCard("トーン") {
                                Picker("トーン", selection: $vm.draftTone) {
                                    ForEach(CommunityPromptPolicy.Tone.allCases, id: \.self) { tone in
                                        Text(toneLabel(tone)).tag(tone)
                                    }
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            pickerCard("カテゴリ") {
                                Picker("カテゴリ", selection: $vm.draftCategory) {
                                    ForEach(CommunityCategory.allCases, id: \.self) { category in
                                        Text(categoryLabel(category)).tag(category)
                                    }
                                }
                            }
                            pickerCard("頻度") {
                                Picker("頻度", selection: $vm.draftSchedule) {
                                    ForEach(CommunityPromptSchedule.allCases, id: \.self) { schedule in
                                        Text(scheduleLabel(schedule)).tag(schedule)
                                    }
                                }
                            }
                            pickerCard("トーン") {
                                Picker("トーン", selection: $vm.draftTone) {
                                    ForEach(CommunityPromptPolicy.Tone.allCases, id: \.self) { tone in
                                        Text(toneLabel(tone)).tag(tone)
                                    }
                                }
                            }
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            pickerCard("長さ") {
                                Picker("長さ", selection: $vm.draftPromptLength) {
                                    ForEach(CommunityPromptPolicy.PromptLength.allCases, id: \.self) { length in
                                        Text(promptLengthLabel(length)).tag(length)
                                    }
                                }
                            }
                            pickerCard("共有方針") {
                                Picker("共有方針", selection: $vm.draftPrivacyLevel) {
                                    ForEach(CommunityPromptPolicy.PrivacyLevel.allCases, id: \.self) { level in
                                        Text(privacyLabel(level)).tag(level)
                                    }
                                }
                            }
                            pickerCard("答え方") {
                                Picker("答え方", selection: $vm.draftAnswerStyle) {
                                    ForEach(CommunityPromptPolicy.AnswerStyle.allCases, id: \.self) { style in
                                        Text(answerStyleLabel(style)).tag(style)
                                    }
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            pickerCard("長さ") {
                                Picker("長さ", selection: $vm.draftPromptLength) {
                                    ForEach(CommunityPromptPolicy.PromptLength.allCases, id: \.self) { length in
                                        Text(promptLengthLabel(length)).tag(length)
                                    }
                                }
                            }
                            pickerCard("共有方針") {
                                Picker("共有方針", selection: $vm.draftPrivacyLevel) {
                                    ForEach(CommunityPromptPolicy.PrivacyLevel.allCases, id: \.self) { level in
                                        Text(privacyLabel(level)).tag(level)
                                    }
                                }
                            }
                            pickerCard("答え方") {
                                Picker("答え方", selection: $vm.draftAnswerStyle) {
                                    ForEach(CommunityPromptPolicy.AnswerStyle.allCases, id: \.self) { style in
                                        Text(answerStyleLabel(style)).tag(style)
                                    }
                                }
                            }
                        }
                    }

                    TextField("絵文字 / アイコン", text: $vm.draftEmoji)
                        .textFieldStyle(.roundedBorder)

                    TextField("タグ（カンマ区切り）", text: $vm.draftTagsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    TextField("ブロックしたい語（任意・カンマ区切り）", text: $vm.draftBlockedWordsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    TextField("カスタムお題の種（改行区切り）", text: $vm.draftCustomPromptSeedsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)

                    TextField("次のお題を固定したいときの一文（任意）", text: $vm.draftPinnedPromptText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    themePickerSection
                }
            }

            CommunityLiteSharePreviewCard(
                model: creatorDraftPreviewModel
            )

            Card("作成プレビューのお題", decorationId: vm.draftThemeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.draftPromptBundle.primary.text)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    if !vm.draftPromptBundle.alternates.isEmpty {
                        Text("候補")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(vm.draftPromptBundle.alternates, id: \.id) { alternate in
                            Text("・\(alternate.text)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Card("7日 / 4週プレビュー", decorationId: vm.draftThemeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.draftPromptPreviewWindow, id: \.id) { prompt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.dateKey ?? prompt.weekKey ?? prompt.id)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(prompt.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button {
                vm.createCommunity()
            } label: {
                Label(vm.canCreateCommunity ? "コミュニティを作る" : "コミュニティ作成は準備中", systemImage: vm.canCreateCommunity ? "plus.circle.fill" : "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canCreateCommunity)

            #if DEBUG
            Button {
                vm.toggleDebugCreatorOverride()
            } label: {
                Label(
                    vm.debugCreatorOverrideEnabled ? "DEBUG: Creator Pass モックをOFF" : "DEBUG: Creator Pass モックをON",
                    systemImage: "hammer"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            #endif
        }
    }

    private var themePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("部屋の見た目 / お題パック")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.ownedDecorationItems, id: \.id) { item in
                        Button {
                            vm.draftThemeDecorationId = item.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.caption.weight(.semibold))
                                Text(GachaThemePresentation.itemTypeLabel(for: item))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(vm.draftThemeDecorationId == item.id ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let themeId = vm.draftThemeDecorationId,
               let item = CardDecorationCatalog.byId(themeId) {
                Text("\(item.name) を部屋テーマに設定中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profileExchangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "プロフィールカード",
                subtitle: "いま装備しているテーマで、プロフィールや招待を共有できます。"
            )

            CommunityLiteSharePreviewCard(
                model: profileModel(includeStreak: vm.includeStreakInProfileShare)
            )

            Toggle("連続記録もプロフィールカードに入れる", isOn: $vm.includeStreakInProfileShare)
                .font(.subheadline)

            actionButtons(
                primaryTitle: "プロフィールカードを共有",
                primarySystemImage: "person.crop.rectangle",
                primaryAction: { shareProfileCard() },
                secondaryTitle: "招待リンクを共有",
                secondarySystemImage: "link",
                secondaryAction: { shareInviteLink() }
            )
        }
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "続けている記録",
                subtitle: "公開ランキングを使わずに、自分の節目だけを共有できます。"
            )

            CommunityLiteSharePreviewCard(
                model: achievementModel
            )

            Button {
                shareAchievementCard()
            } label: {
                Label("連続記録カードを共有", systemImage: "flame")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let lastMessage = vm.lastMessage {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reactionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リアクションスタンプ")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CommunityLiteReactionStamp.allCases) { stamp in
                        Button {
                            vm.selectedReaction = stamp
                        } label: {
                            HStack(spacing: 8) {
                                Text(stamp.rawValue)
                                Text(stamp.label)
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(vm.selectedReaction == stamp ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionButtons(
        primaryTitle: String,
        primarySystemImage: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondarySystemImage: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: secondaryAction) {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: secondaryAction) {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func editorCard(
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))

            TextEditor(text: text)
                .frame(minHeight: 120)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .scrollContentBackground(.hidden)

            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func pickerCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labelCapsule(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private func categoryLabel(_ category: CommunityCategory) -> String {
        switch category {
        case .games: return "ゲーム"
        case .study: return "勉強"
        case .music: return "音楽"
        case .anime: return "アニメ"
        case .books: return "本"
        case .fitness: return "フィットネス"
        case .dailyLife: return "日常"
        case .custom: return "カスタム"
        }
    }

    private func scheduleLabel(_ schedule: CommunityPromptSchedule) -> String {
        switch schedule {
        case .daily: return "毎日"
        case .weekly: return "毎週"
        }
    }

    private func toneLabel(_ tone: CommunityPromptPolicy.Tone) -> String {
        switch tone {
        case .casual: return "カジュアル"
        case .deep: return "深め"
        case .fun: return "楽しく"
        case .nostalgic: return "懐かしく"
        case .challenge: return "挑戦"
        }
    }

    private func promptLengthLabel(_ length: CommunityPromptPolicy.PromptLength) -> String {
        switch length {
        case .short: return "短め"
        case .medium: return "中くらい"
        }
    }

    private func privacyLabel(_ level: CommunityPromptPolicy.PrivacyLevel) -> String {
        switch level {
        case .safeToShare: return "共有しやすい"
        case .privateReflection: return "内省向き"
        }
    }

    private func answerStyleLabel(_ style: CommunityPromptPolicy.AnswerStyle) -> String {
        switch style {
        case .onePhrase: return "ひとこと"
        case .shortMemo: return "短いメモ"
        case .ranking: return "ランキング"
        case .recommendation: return "おすすめ"
        }
    }

    private func weeklyChallengeModel(includeAnswer: Bool) -> CommunityLiteShareCardModel {
        CommunityLiteShareCardModel(
            kindTitle: "今週のチャレンジ",
            headline: vm.weeklyChallenge.title,
            body: includeAnswer
                ? (vm.weeklyResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "回答はまだ入力されていません"
                    : vm.weeklyResponse.trimmingCharacters(in: .whitespacesAndNewlines))
                : vm.weeklyChallenge.prompt,
            footer: vm.weeklyChallenge.hashtag,
            decorationId: vm.selectedDecorationId,
            badgeText: vm.weeklyChallenge.badgeTitle,
            titlePlate: vm.equippedTitle,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private func communityPromptModel(
        for community: CommunityTemplate,
        includeAnswer: Bool
    ) -> CommunityLiteShareCardModel {
        let promptText = vm.currentCommunityPromptBundle?.primary.text ?? "お題を準備しています"
        let answerText = vm.communityAnswerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = includeAnswer && !answerText.isEmpty ? answerText : promptText

        return CommunityLiteShareCardModel(
            kindTitle: "コミュニティお題",
            headline: "\(community.emoji) \(community.name)",
            body: body,
            footer: community.category == .games ? "#ひとこと日記 #ゲーム日記" : "#ひとこと日記",
            decorationId: community.themeDecorationId ?? vm.selectedDecorationId,
            badgeText: vm.selectedCommunityPromptLabel,
            titlePlate: vm.equippedTitle,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private var creatorDraftPreviewModel: CommunityLiteShareCardModel {
        CommunityLiteShareCardModel(
            kindTitle: "コミュニティ作成プレビュー",
            headline: "\(vm.draftCommunityPreview.emoji) \(vm.draftCommunityPreview.name)",
            body: vm.draftPromptBundle.primary.text,
            footer: vm.draftCommunityPreview.category == .games ? "#ひとこと日記 #ゲーム日記" : "#ひとこと日記",
            decorationId: vm.draftCommunityPreview.themeDecorationId ?? vm.selectedDecorationId,
            badgeText: vm.canCreateCommunity ? "作成可能" : "準備中",
            titlePlate: vm.equippedTitle,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private func profileModel(includeStreak: Bool) -> CommunityLiteShareCardModel {
        let streakLine = includeStreak ? "連続記録 \(vm.streak)日" : "プロフィールを共有"
        return CommunityLiteShareCardModel(
            kindTitle: "プロフィールカード",
            headline: vm.displayName,
            body: streakLine,
            footer: "#ひとこと日記",
            decorationId: vm.selectedDecorationId,
            badgeText: GachaThemePresentation.itemTypeLabel(for: vm.equippedItem),
            titlePlate: vm.equippedTitle,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private var achievementModel: CommunityLiteShareCardModel {
        CommunityLiteShareCardModel(
            kindTitle: "続けている記録",
            headline: "\(vm.streak)日ストリーク",
            body: "今週も続いています",
            footer: "#ひとこと日記",
            decorationId: vm.selectedDecorationId,
            badgeText: "継続中",
            titlePlate: vm.equippedTitle,
            reaction: vm.selectedReaction.rawValue
        )
    }

    private func shareWeeklyChallengeCard() {
        let text = vm.weeklyChallengeShareText()
        let image = CommunityLiteShareCardRenderer.render(model: weeklyChallengeModel(includeAnswer: vm.includeWeeklyResponseInShare))
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareSelectedCommunityCard(includeAnswer: Bool) {
        guard let community = vm.selectedCommunity,
              let text = vm.communityPromptShareText(includeAnswer: includeAnswer) else {
            return
        }
        let image = CommunityLiteShareCardRenderer.render(
            model: communityPromptModel(for: community, includeAnswer: includeAnswer)
        )
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareJoinedCommunityCard() {
        guard let community = vm.selectedCommunity,
              let text = vm.joinedCommunityShareText() else {
            return
        }
        let image = CommunityLiteShareCardRenderer.render(
            model: communityPromptModel(for: community, includeAnswer: false)
        )
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareProfileCard() {
        let text = vm.profileShareText()
        let image = CommunityLiteShareCardRenderer.render(model: profileModel(includeStreak: vm.includeStreakInProfileShare))
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareAchievementCard() {
        let text = vm.achievementShareText()
        let image = CommunityLiteShareCardRenderer.render(model: achievementModel)
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func shareInviteLink() {
        guard let inviteURL = vm.inviteURL else {
            vm.lastMessage = "招待リンクをまだ生成できません"
            return
        }
        shareSheetItems = ShareItemsBuilder.build(text: vm.inviteShareText, image: nil, url: inviteURL)
        isPresentingShareSheet = true
    }
}

private struct CommunityLiteShareCardModel: Equatable {
    let kindTitle: String
    let headline: String
    let body: String
    let footer: String
    let decorationId: String
    let badgeText: String?
    let titlePlate: String?
    let reaction: String
}

private struct CommunityLiteSharePreviewCard: View {
    let model: CommunityLiteShareCardModel

    var body: some View {
        CommunityLiteShareCardView(model: model)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
    }
}

private struct CommunityLiteShareCardView: View {
    let model: CommunityLiteShareCardModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Card(nil, decorationId: model.decorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.kindTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("ひとこと日記")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let badgeText = model.badgeText {
                            Text(badgeText)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }

                    Text(model.headline)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let titlePlate = model.titlePlate {
                        Text(titlePlate)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    Text(model.body)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    HStack {
                        Text(model.footer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Spacer()

                        Text(model.reaction)
                            .font(.title3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private enum CommunityLiteShareCardRenderer {
    @MainActor
    static func render(
        model: CommunityLiteShareCardModel,
        scale: CGFloat? = nil
    ) -> UIImage? {
        let content = CommunityLiteShareCardView(model: model)
            .frame(width: 900, height: 900)
            .padding(32)

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale ?? UIScreen.main.scale
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
