import SwiftUI
import StoreKit
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
    @Published private(set) var socialProfiles: [SocialUserProfileSummary] = []
    @Published private(set) var dmConversations: [DirectMessageConversation] = []

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
    @Published var selectedConversationId: String? = nil
    @Published var dmDraftText: String = ""

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
    private let updateMyProfile: UpdateMyProfileUseCase
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
        updateMyProfile: UpdateMyProfileUseCase,
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
        self.updateMyProfile = updateMyProfile
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
        "公開フィードはまだありません。参加は無料のまま、フォローやDMは安全なローカル導線から段階的に整えています。"
    }

    var joinedCommunities: [CommunityTemplate] {
        communities.filter(\.isJoined)
    }

    var availableCommunities: [CommunityTemplate] {
        communities.filter { $0.category == .games || !$0.isOfficialPreset || FeatureFlags.gameCommunityEnabled }
    }

    var followingProfiles: [SocialUserProfileSummary] {
        let following = Set(getMyProfile().followingUserIDs)
        return socialProfiles.filter { following.contains($0.id) }
    }

    var recommendedProfiles: [SocialUserProfileSummary] {
        let following = Set(getMyProfile().followingUserIDs)
        return socialProfiles.filter { !following.contains($0.id) }
    }

    var selectedConversation: DirectMessageConversation? {
        guard let selectedConversationId else { return nil }
        return dmConversations.first { $0.id == selectedConversationId }
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
        dmConversations = profile.dmConversations
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
        reloadSocialProfiles(profile: profile)
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

    func isFollowing(_ profileID: String) -> Bool {
        getMyProfile().followingUserIDs.contains(profileID)
    }

    func isBlocked(_ profileID: String) -> Bool {
        getMyProfile().blockedUserIDs.contains(profileID)
    }

    func isReported(_ profileID: String) -> Bool {
        getMyProfile().reportedUserIDs.contains(profileID)
    }

    func canSendDM(to profile: SocialUserProfileSummary) -> Bool {
        SocialSupport.canUseDirectMessage(
            with: profile,
            followingUserIDs: Set(getMyProfile().followingUserIDs),
            blockedUserIDs: Set(getMyProfile().blockedUserIDs)
        )
    }

    func toggleFollow(_ profile: SocialUserProfileSummary) {
        let me = getMyProfile()
        let updated = SocialSupport.toggledFollowIDs(current: me.followingUserIDs, targetUserID: profile.id)
        _ = updateMyProfile(followingUserIDs: updated)
        reloadSocialProfiles(profile: getMyProfile())
        lastMessage = updated.contains(profile.id) ? "フォローしました" : "フォローを解除しました"
    }

    func toggleBlock(_ profile: SocialUserProfileSummary) {
        let me = getMyProfile()
        let updatedBlocked = SocialSupport.blockedIDsAfterBlocking(current: me.blockedUserIDs, targetUserID: profile.id)
        let updatedFollowing = me.followingUserIDs.filter { $0 != profile.id }
        let updatedConversations = me.dmConversations.filter { $0.participantUserID != profile.id }
        _ = updateMyProfile(
            followingUserIDs: updatedFollowing,
            blockedUserIDs: updatedBlocked,
            dmConversations: updatedConversations
        )
        reloadSocialProfiles(profile: getMyProfile())
        dmConversations = getMyProfile().dmConversations
        lastMessage = updatedBlocked.contains(profile.id) ? "ブロックしました" : "ブロックを解除しました"
    }

    func report(_ profile: SocialUserProfileSummary) {
        let me = getMyProfile()
        let updated = SocialSupport.reportedIDsAfterReporting(current: me.reportedUserIDs, targetUserID: profile.id)
        _ = updateMyProfile(reportedUserIDs: updated)
        reloadSocialProfiles(profile: getMyProfile())
        lastMessage = "通報メモをこの端末に保存しました"
    }

    func sendDraftMessage(to profile: SocialUserProfileSummary) {
        guard canSendDM(to: profile) else {
            lastMessage = "DMは相互フォローの相手とのみ利用できます"
            return
        }
        let trimmed = SocialSupport.sanitizedMessageBody(dmDraftText)
        guard !trimmed.isEmpty else {
            lastMessage = "メッセージが空のため送信されませんでした"
            return
        }

        let existing = getMyProfile().dmConversations.first { $0.participantUserID == profile.id }
        let updatedConversation = SocialSupport.conversationAfterSending(
            existing: existing,
            to: profile,
            body: trimmed,
            sentAt: Date()
        )
        let others = getMyProfile().dmConversations.filter { $0.participantUserID != profile.id }
        let merged = [updatedConversation] + others
        _ = updateMyProfile(dmConversations: merged)
        dmConversations = getMyProfile().dmConversations
        selectedConversationId = updatedConversation.id
        dmDraftText = ""
        lastMessage = "この端末にDMの下書きを保存しました"
    }

    func deleteConversation(_ conversationID: String) {
        let remaining = getMyProfile().dmConversations.filter { $0.id != conversationID }
        _ = updateMyProfile(dmConversations: remaining)
        dmConversations = getMyProfile().dmConversations
        if selectedConversationId == conversationID {
            selectedConversationId = dmConversations.first?.id
        }
        lastMessage = "会話を削除しました"
    }

    func profiles(for community: CommunityTemplate) -> [SocialUserProfileSummary] {
        let all = socialProfiles.filter { !$0.isLocalOnly || community.category == .games }
        return Array(all.prefix(3))
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

    private func reloadSocialProfiles(profile: UserProfile) {
        socialProfiles = SocialSupport.applyRelationshipState(
            profiles: SocialSupport.demoProfiles(),
            followingUserIDs: Set(profile.followingUserIDs),
            blockedUserIDs: Set(profile.blockedUserIDs),
            reportedUserIDs: Set(profile.reportedUserIDs)
        )
        dmConversations = profile.dmConversations
            .sorted { $0.updatedAt > $1.updatedAt }
        if selectedConversationId == nil {
            selectedConversationId = dmConversations.first?.id
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
    @EnvironmentObject private var iap: IAPStore

    @State private var shareSheetItems: [Any] = []
    @State private var isPresentingShareSheet = false
    @State private var selectedSection: HubSection = .joined

    private enum HubSection: String, CaseIterable, Identifiable {
        case joined = "参加中"
        case rooms = "ゲーム部屋"
        case challenge = "チャレンジ"
        case follow = "フォロー"
        case dm = "DM"
        case creator = "作成"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .joined: return "person.2.fill"
            case .rooms: return "gamecontroller.fill"
            case .challenge: return "sparkles"
            case .follow: return "person.crop.circle.badge.plus"
            case .dm: return "message.fill"
            case .creator: return "crown.fill"
            }
        }
    }

    private var selectedConversationProfile: SocialUserProfileSummary? {
        if let selectedConversationId = vm.selectedConversationId,
           let profile = vm.socialProfiles.first(where: { $0.id == selectedConversationId }) {
            return profile
        }
        return vm.dmConversations.first.flatMap { conversation in
            vm.socialProfiles.first(where: { $0.id == conversation.participantUserID })
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                heroCard
                dashboardCards
                sectionPicker
                activeSectionContent

                if let lastMessage = vm.lastMessage {
                    Text(lastMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: AppChrome.standardPageMaxWidth)
            .padding(.horizontal, AppChrome.screenHorizontalPadding)
            .padding(.top, AppChrome.standardPageTopPadding)
            .padding(.bottom, AppChrome.standardPageBottomPadding)
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
        PageHeroCard(
            eyebrow: "参加してつながる",
            title: "みんなの部屋",
            subtitle: "ゲームや好きなテーマの部屋に無料で参加して、お題にひとこと答えられます。公開フィードを使わず、安心して楽しめる導線から先に整えています。",
            accent: .green
        ) {
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

            LazyVGrid(columns: [.init(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                SummaryMetricTile(
                    title: "参加中",
                    value: "\(vm.joinedCommunities.count)部屋",
                    detail: vm.joinedCommunities.isEmpty ? "まだ参加していません" : "部屋ごとのお題を確認できます",
                    systemImage: "person.2.fill",
                    tint: .green
                )
                SummaryMetricTile(
                    title: "ゲーム部屋",
                    value: "\(vm.availableCommunities.count)部屋",
                    detail: "気になるテーマを探せます",
                    systemImage: "gamecontroller.fill",
                    tint: .blue
                )
                SummaryMetricTile(
                    title: "フォロー",
                    value: "\(vm.followingProfiles.count)人",
                    detail: "相互フォローでDMできます",
                    systemImage: "person.crop.circle.badge.plus",
                    tint: .purple
                )
                SummaryMetricTile(
                    title: "Creator Pass",
                    value: vm.creatorEntitlement.hasCreatorPass ? "有効" : "未加入",
                    detail: "コミュニティ作成を解放",
                    systemImage: "crown.fill",
                    tint: .orange
                )
            }

            Text("日記の回答は自動で公開されません。DMは相互フォローの相手とのみ使えます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dashboardCards: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            dashboardCard(
                section: .joined,
                title: "参加中",
                subtitle: vm.joinedCommunities.isEmpty ? "まだ0部屋" : "\(vm.joinedCommunities.count)部屋",
                accent: .green
            )
            dashboardCard(
                section: .rooms,
                title: "ゲーム部屋",
                subtitle: "\(vm.availableCommunities.count)部屋から探す",
                accent: .blue
            )
            dashboardCard(
                section: .follow,
                title: "フォロー",
                subtitle: vm.followingProfiles.isEmpty ? "つながりを作る" : "\(vm.followingProfiles.count)人をフォロー中",
                accent: .purple
            )
            dashboardCard(
                section: .creator,
                title: "作成",
                subtitle: vm.creatorEntitlement.hasCreatorPass ? "Creator Pass 有効" : "Creator Pass を確認",
                accent: .orange
            )
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HubSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.rawValue, systemImage: section.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selectedSection == section
                                ? Color.accentColor.opacity(0.18)
                                : Color(uiColor: .secondarySystemBackground),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedSection == section
                                        ? Color.accentColor.opacity(0.22)
                                        : Color.primary.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var activeSectionContent: some View {
        switch selectedSection {
        case .joined:
            joinedSection
        case .rooms:
            roomsSection
        case .challenge:
            challengeSection
        case .follow:
            followSection
        case .dm:
            dmSection
        case .creator:
            creatorSection
        }
    }

    private var joinedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "参加中の部屋",
                subtitle: "いま参加している部屋だけをまとめて見られます。無料参加のまま、お題に答えたり共有したりできます。"
            )

            if vm.joinedCommunities.isEmpty {
                EmptyStateCard(
                    title: "まだ参加している部屋はありません",
                    message: "気になるゲーム部屋を1つ選ぶと、部屋ごとのお題を無料で楽しめます。",
                    systemImage: "person.2"
                )
            } else {
                joinedCommunitiesStrip

                if let community = vm.selectedCommunity, community.isJoined {
                    communityDetailSection(community)
                } else {
                    EmptyStateCard(
                        title: "参加中の部屋を選ぶと詳細が表示されます",
                        message: "上のチップから見たい部屋を選ぶと、お題や回答欄、共有カードを確認できます。",
                        systemImage: "hand.tap"
                    )
                }
            }
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "ゲーム部屋を探す",
                subtitle: "参加は無料です。気になるテーマを選ぶと、その部屋向けのお題をすぐ確認できます。"
            )

            communityCatalogGrid

            if let community = vm.selectedCommunity {
                communityDetailSection(community)
            } else {
                EmptyStateCard(
                    title: "部屋を選ぶと詳細が表示されます",
                    message: "気になるゲーム部屋を1つ選ぶと、今日のお題プレビューや参加方法を確認できます。",
                    systemImage: "rectangle.grid.1x2"
                )
            }
        }
    }

    private var challengeSection: some View {
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

            streakSection
        }
    }

    private var followSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "フォロー",
                subtitle: "フォローすると相手のプロフィールカードを見つけやすくなります。公開検索は使わず、ローカルなおすすめカードだけを表示しています。"
            )

            Card("安全なつながり方", decorationId: vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.socialHeaderText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            InfoBadge(title: "公開検索なし", systemImage: "eye.slash", tint: .indigo)
                            InfoBadge(title: "通報・ブロック可", systemImage: "hand.raised", tint: .orange)
                            InfoBadge(title: "DMは相互フォローのみ", systemImage: "message.badge", tint: .blue)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            InfoBadge(title: "公開検索なし", systemImage: "eye.slash", tint: .indigo)
                            InfoBadge(title: "通報・ブロック可", systemImage: "hand.raised", tint: .orange)
                            InfoBadge(title: "DMは相互フォローのみ", systemImage: "message.badge", tint: .blue)
                        }
                    }
                }
            }

            if vm.followingProfiles.isEmpty {
                EmptyStateCard(
                    title: "まだフォローしている相手はいません",
                    message: "まずはおすすめのプロフィールカードを見て、気になる相手をフォローしてみましょう。",
                    systemImage: "person.crop.circle.badge.plus"
                )
            } else {
                socialProfileSection(title: "フォロー中", profiles: vm.followingProfiles)
            }

            if !vm.recommendedProfiles.isEmpty {
                socialProfileSection(title: "おすすめプロフィール", profiles: vm.recommendedProfiles)
            }

            profileExchangeSection
        }
    }

    private var dmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "DM",
                subtitle: "DMは相互フォローの相手とのみ利用できます。現在はこの端末で流れを確認できる安全な下書きDMです。"
            )

            Card("DMの安全設定", decorationId: vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("不快な相手はブロック・通報できます。画像やリンク共有はまだ無効で、日記の回答も自動では入りません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            InfoBadge(title: "相互フォロー限定", systemImage: "person.2.badge.gearshape", tint: .blue)
                            InfoBadge(title: "画像送信なし", systemImage: "photo.slash", tint: .purple)
                            InfoBadge(title: "通報・ブロック可", systemImage: "hand.raised", tint: .orange)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            InfoBadge(title: "相互フォロー限定", systemImage: "person.2.badge.gearshape", tint: .blue)
                            InfoBadge(title: "画像送信なし", systemImage: "photo.slash", tint: .purple)
                            InfoBadge(title: "通報・ブロック可", systemImage: "hand.raised", tint: .orange)
                        }
                    }
                }
            }

            if vm.dmConversations.isEmpty && selectedConversationProfile == nil {
                EmptyStateCard(
                    title: "まだDMはありません",
                    message: "相互フォローの相手ができると、この画面から安全に下書きDMを試せます。",
                    systemImage: "message"
                )
            } else {
                if !vm.dmConversations.isEmpty {
                    conversationPicker
                }

                if let profile = selectedConversationProfile {
                    conversationDetailCard(
                        profile: profile,
                        conversation: vm.dmConversations.first(where: { $0.participantUserID == profile.id })
                    )
                }
            }

            if !vm.followingProfiles.isEmpty {
                socialProfileSection(title: "DM候補", profiles: vm.followingProfiles)
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

                            Text("お題例: \(vm.selectedCommunityId == community.id ? (vm.currentCommunityPromptBundle?.primary.text ?? "参加すると専用お題を見られます") : "参加すると専用お題を見られます")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

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

            if FeatureFlags.socialGraphEnabled {
                participantProfilesSection(for: community)
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

            creatorPassStatusCard

            Card("作成プレビュー", decorationId: vm.draftThemeDecorationId ?? vm.selectedDecorationId) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("参加は無料です。作成はCreator Pass機能です。Creator Passでコミュニティ作成とお題カスタマイズを解放します。")
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("基本情報")
                            .font(.subheadline.weight(.semibold))
                        Text("まずは名前・説明・カテゴリを決めると、下のプレビューが更新されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("コミュニティ名", text: $vm.draftName)
                            .textFieldStyle(.roundedBorder)

                        TextField("短い説明", text: $vm.draftDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

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

                    DisclosureGroup("詳細カスタマイズ") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("必要なときだけ、お題の種や共有方針を細かく調整できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            TextField("ブロックしたい語（任意・カンマ区切り）", text: $vm.draftBlockedWordsText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)

                            TextField("カスタムお題の種（改行区切り）", text: $vm.draftCustomPromptSeedsText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)

                            TextField("次のお題を固定したいときの一文（任意）", text: $vm.draftPinnedPromptText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)
                        }
                        .padding(.top, 8)
                    }

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
                Label(vm.canCreateCommunity ? "コミュニティを作る" : "Creator Passで作成を解放", systemImage: vm.canCreateCommunity ? "plus.circle.fill" : "lock.fill")
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

    private var creatorPassStatusCard: some View {
        let previewState = MonetizationShopSupport.creatorPassState(
            availability: iap.productLoadState,
            creatorPassLoaded: !iap.creatorPassProducts.isEmpty,
            displayPrice: iap.creatorPassProducts.first?.displayPrice
        )

        return AppSectionCard(
            title: "Creator Pass",
            subtitle: "コミュニティ作成・お題カスタマイズ・テーマ設定を解放します。参加者は無料のままです。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        PremiumBadge(title: vm.creatorEntitlement.hasCreatorPass ? "作成機能が有効" : "作成機能を解放")
                        InfoBadge(title: "参加は無料", systemImage: "person.badge.plus", tint: .green)
                        InfoBadge(title: "公開フィードなし", systemImage: "shield", tint: .indigo)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        PremiumBadge(title: vm.creatorEntitlement.hasCreatorPass ? "作成機能が有効" : "作成機能を解放")
                        InfoBadge(title: "参加は無料", systemImage: "person.badge.plus", tint: .green)
                        InfoBadge(title: "公開フィードなし", systemImage: "shield", tint: .indigo)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.creatorEntitlement.hasCreatorPass ? "この端末ではコミュニティ作成が有効です。" : previewState.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(iap.creatorPassBenefitLines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if vm.creatorEntitlement.hasCreatorPass {
                    Label("Creator Pass 有効", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else if !iap.creatorPassProducts.isEmpty {
                    ForEach(iap.creatorPassProducts, id: \.id) { product in
                        Button {
                            Task { await iap.purchase(product) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("コミュニティ作成とお題カスタマイズを解放")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!previewState.isPurchaseEnabled)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Creator Pass を確認")
                                    .font(.subheadline.weight(.semibold))
                                Text("App Storeの商品情報を確認中です")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(previewState.displayPrice ?? "--")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("反映に時間がかかる場合があります。価格が確認できるまでは購入ボタンを表示せず、機能の内容だけを先に確認できるようにしています。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.10),
                                Color(uiColor: .secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.orange.opacity(0.14), lineWidth: 1)
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await iap.reloadProducts() }
                        } label: {
                            Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await iap.restoreCreatorPass() }
                        } label: {
                            Label("購入情報を復元", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { await iap.reloadProducts() }
                        } label: {
                            Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await iap.restoreCreatorPass() }
                        } label: {
                            Label("購入情報を復元", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
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
        }
    }

    private var conversationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.dmConversations) { conversation in
                    Button {
                        vm.selectedConversationId = conversation.id
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.participantDisplayName)
                                .font(.caption.weight(.semibold))
                            Text(conversation.messages.last?.body ?? "新しいDM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(vm.selectedConversationId == conversation.id ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func conversationDetailCard(
        profile: SocialUserProfileSummary,
        conversation: DirectMessageConversation?
    ) -> some View {
        Card("DM", decorationId: profile.equippedThemeId) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.headline)
                        if let title = profile.profileTitle {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let conversation {
                        Button("削除") {
                            vm.deleteConversation(conversation.id)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let conversation, !conversation.messages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conversation.messages.suffix(6)) { message in
                            VStack(alignment: message.sender == .me ? .trailing : .leading, spacing: 4) {
                                Text(message.sender == .me ? "自分" : profile.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(message.body)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        message.sender == .me
                                        ? Color.accentColor.opacity(0.14)
                                        : Color(uiColor: .secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: message.sender == .me ? .trailing : .leading)
                        }
                    }
                } else {
                    Text("まだDMは保存されていません。送信内容はこの端末にのみ下書き保存されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("DMを入力", text: $vm.dmDraftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            vm.sendDraftMessage(to: profile)
                        } label: {
                            Label("DMを保存", systemImage: "paperplane")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            Button(vm.isBlocked(profile.id) ? "ブロック解除" : "ブロック") {
                                vm.toggleBlock(profile)
                            }
                            Button(vm.isReported(profile.id) ? "通報メモ済み" : "通報メモを保存") {
                                vm.report(profile)
                            }
                            .disabled(vm.isReported(profile.id))
                        } label: {
                            Label("安全", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(spacing: 10) {
                        Button {
                            vm.sendDraftMessage(to: profile)
                        } label: {
                            Label("DMを保存", systemImage: "paperplane")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            Button(vm.isBlocked(profile.id) ? "ブロック解除" : "ブロック") {
                                vm.toggleBlock(profile)
                            }
                            Button(vm.isReported(profile.id) ? "通報メモ済み" : "通報メモを保存") {
                                vm.report(profile)
                            }
                            .disabled(vm.isReported(profile.id))
                        } label: {
                            Label("安全", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func socialProfileSection(title: String, profiles: [SocialUserProfileSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            LazyVStack(spacing: 10) {
                ForEach(profiles) { profile in
                    socialProfileCard(profile)
                }
            }
        }
    }

    private func participantProfilesSection(for community: CommunityTemplate) -> some View {
        let profiles = vm.profiles(for: community)
        return VStack(alignment: .leading, spacing: 8) {
            Text("参加者カード")
                .font(.subheadline.weight(.semibold))
            Text("公開コメントやランキングはまだありません。プロフィールカードを起点に、安全なつながり方だけを表示しています。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if profiles.isEmpty {
                EmptyStateCard(
                    title: "参加者カードはまだありません",
                    message: "今後、フォローしている相手のカードをここから見つけやすくしていきます。",
                    systemImage: "person.crop.rectangle.stack"
                )
            } else {
                ForEach(profiles) { profile in
                    socialProfileCard(profile)
                }
            }
        }
    }

    private func socialProfileCard(_ profile: SocialUserProfileSummary) -> some View {
        Card(nil, decorationId: profile.equippedThemeId) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.headline)
                        if let title = profile.profileTitle {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if vm.isBlocked(profile.id) {
                        InfoBadge(title: "ブロック中", systemImage: "hand.raised.fill", tint: .orange)
                    } else if vm.isFollowing(profile.id) {
                        EquippedItemBadge(title: "フォロー中")
                    } else {
                        InfoBadge(title: "ローカルカード", systemImage: "person.crop.square", tint: .indigo)
                    }
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        InfoBadge(title: "参加中 \(profile.joinedCommunityCount)部屋", systemImage: "person.2", tint: .green)
                        if profile.supportsMutualDM {
                            InfoBadge(title: "相互フォローでDM可", systemImage: "message", tint: .blue)
                        } else {
                            InfoBadge(title: "DM準備中", systemImage: "message.slash", tint: .secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "参加中 \(profile.joinedCommunityCount)部屋", systemImage: "person.2", tint: .green)
                        if profile.supportsMutualDM {
                            InfoBadge(title: "相互フォローでDM可", systemImage: "message", tint: .blue)
                        } else {
                            InfoBadge(title: "DM準備中", systemImage: "message.slash", tint: .secondary)
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            vm.toggleFollow(profile)
                        } label: {
                            Label(vm.isFollowing(profile.id) ? "フォロー解除" : "フォローする", systemImage: vm.isFollowing(profile.id) ? "person.badge.minus" : "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.selectedConversationId = profile.id
                            selectedSection = .dm
                        } label: {
                            Label("DM", systemImage: "message")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!vm.canSendDM(to: profile))

                        Menu {
                            Button(vm.isBlocked(profile.id) ? "ブロック解除" : "ブロック") {
                                vm.toggleBlock(profile)
                            }
                            Button(vm.isReported(profile.id) ? "通報メモ済み" : "通報メモを保存") {
                                vm.report(profile)
                            }
                            .disabled(vm.isReported(profile.id))
                        } label: {
                            Label("安全", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(spacing: 10) {
                        Button {
                            vm.toggleFollow(profile)
                        } label: {
                            Label(vm.isFollowing(profile.id) ? "フォロー解除" : "フォローする", systemImage: vm.isFollowing(profile.id) ? "person.badge.minus" : "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.selectedConversationId = profile.id
                            selectedSection = .dm
                        } label: {
                            Label("DM", systemImage: "message")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!vm.canSendDM(to: profile))

                        Menu {
                            Button(vm.isBlocked(profile.id) ? "ブロック解除" : "ブロック") {
                                vm.toggleBlock(profile)
                            }
                            Button(vm.isReported(profile.id) ? "通報メモ済み" : "通報メモを保存") {
                                vm.report(profile)
                            }
                            .disabled(vm.isReported(profile.id))
                        } label: {
                            Label("安全", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
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

    private func dashboardCard(
        section: HubSection,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        Button {
            selectedSection = section
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Label(title, systemImage: section.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedSection == section ? accent : Color.secondary.opacity(0.7))
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selectedSection == section ? accent.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            badgeText: vm.canCreateCommunity ? "作成可能" : "Creator Pass",
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
