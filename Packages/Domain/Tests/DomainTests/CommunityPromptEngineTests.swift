import Foundation
import Testing
@testable import Domain

@Suite("Community prompt engine")
struct CommunityPromptEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    @Test("game community prompt generation is deterministic")
    func deterministicGamePrompt() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let community = makeCommunity(id: "games.general", name: "ゲーム好きの部屋", tags: ["games", "general"])

        let first = engine.promptBundle(for: community, referenceDate: date)
        let second = engine.promptBundle(for: community, referenceDate: date)

        #expect(first == second)
    }

    @Test("RPG community differs from FPS community")
    func rpgDiffersFromFps() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let rpg = makeCommunity(id: "games.rpg", name: "RPG好きの部屋", tags: ["games", "rpg"])
        let fps = makeCommunity(id: "games.fps", name: "FPS好きの部屋", tags: ["games", "fps", "competitive"])

        let rpgPrompt = engine.promptBundle(for: rpg, referenceDate: date).primary.text
        let fpsPrompt = engine.promptBundle(for: fps, referenceDate: date).primary.text

        #expect(rpgPrompt != fpsPrompt)
    }

    @Test("same community and week returns same weekly prompt")
    func sameWeekIsStable() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let secondDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 9))!
        var community = makeCommunity(id: "games.weekly", name: "週刊ゲーム部", tags: ["games", "retro"])
        community.promptSchedule = .weekly

        let first = engine.promptBundle(for: community, referenceDate: firstDate).primary
        let second = engine.promptBundle(for: community, referenceDate: secondDate).primary

        #expect(first.weekKey == second.weekKey)
        #expect(first.text == second.text)
    }

    @Test("different week can return different prompt")
    func differentWeekCanDiffer() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let secondDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 28, hour: 12))!
        var community = makeCommunity(id: "games.weekly", name: "週刊ゲーム部", tags: ["games", "retro"])
        community.promptSchedule = .weekly

        let first = engine.promptBundle(for: community, referenceDate: firstDate).primary
        let second = engine.promptBundle(for: community, referenceDate: secondDate).primary

        #expect(first.weekKey != second.weekKey)
        #expect(first.text != second.text)
    }

    @Test("blocked words are not included")
    func blockedWordsExcluded() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        var community = makeCommunity(id: "games.blocked", name: "ゲーム好きの部屋", tags: ["games", "general"])
        community.customPromptSeeds = ["このpromptはNGワードを含む"]
        community.blockedWords = ["ngワード"]

        let prompt = engine.promptBundle(for: community, referenceDate: date).primary.text.lowercased()

        #expect(!prompt.contains("ngワード"))
    }

    @Test("creator prompt policy affects generated prompts")
    func policyAffectsPromptMetadata() {
        let engine = CommunityPromptEngine(calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        var community = makeCommunity(id: "games.private", name: "対戦ゲーム反省会", tags: ["games", "fps", "competitive"])
        community.promptPolicy = CommunityPromptPolicy(
            tone: .challenge,
            promptLength: .medium,
            privacyLevel: .privateReflection,
            answerStyle: .ranking
        )

        let prompt = engine.promptBundle(for: community, referenceDate: date).primary

        #expect(prompt.shareSafe == false)
        #expect(prompt.answerStyle == .ranking)
    }

    @Test("free user can join preset community")
    func joinCommunityWorks() {
        let repo = FakeCommunityRepository(
            communities: [makeCommunity(id: "official.games.general", name: "ゲーム好きの部屋", tags: ["games"])]
        )
        let join = JoinCommunityUseCase(repo: repo, nowProvider: { Date(timeIntervalSince1970: 1234) })

        join(communityId: "official.games.general")

        #expect(repo.community(id: "official.games.general")?.isJoined == true)
    }

    @Test("leaving community works")
    func leaveCommunityWorks() {
        var joined = makeCommunity(id: "official.games.general", name: "ゲーム好きの部屋", tags: ["games"])
        joined.isJoined = true
        joined.joinedAt = Date(timeIntervalSince1970: 1234)
        let repo = FakeCommunityRepository(communities: [joined])
        let leave = LeaveCommunityUseCase(repo: repo)

        leave(communityId: "official.games.general")

        #expect(repo.community(id: "official.games.general")?.isJoined == false)
        #expect(repo.community(id: "official.games.general")?.joinedAt == nil)
    }

    private func makeCommunity(id: String, name: String, tags: [String]) -> CommunityTemplate {
        var community = CommunityTemplate(
            id: id,
            name: name,
            description: "ゲームについて語る部屋",
            category: .games,
            emoji: "🎮",
            createdAt: Date(timeIntervalSince1970: 1000),
            creatorDisplayName: "official",
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
            themeDecorationId: "arcade",
            allowedTags: tags,
            blockedWords: [],
            isOfficialPreset: true,
            requiresCreatorPassToCreate: false,
            isJoined: false
        )
        community.normalize()
        return community
    }
}

private final class FakeCommunityRepository: CommunityTemplateRepository, @unchecked Sendable {
    private var communities: [CommunityTemplate]
    private var responses: [CommunityResponse]

    init(
        communities: [CommunityTemplate] = [],
        responses: [CommunityResponse] = []
    ) {
        self.communities = communities
        self.responses = responses
    }

    func listCommunities() -> [CommunityTemplate] {
        communities
    }

    func community(id: String) -> CommunityTemplate? {
        communities.first { $0.id == id }
    }

    func saveCommunity(_ community: CommunityTemplate) {
        if let index = communities.firstIndex(where: { $0.id == community.id }) {
            communities[index] = community
        } else {
            communities.append(community)
        }
    }

    func deleteCommunity(id: String) {
        communities.removeAll { $0.id == id }
    }

    func setJoined(_ isJoined: Bool, communityId: String, joinedAt: Date?) {
        guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
        communities[index].isJoined = isJoined
        communities[index].joinedAt = joinedAt
    }

    func listResponses() -> [CommunityResponse] {
        responses
    }

    func response(communityId: String, promptKey: String) -> CommunityResponse? {
        responses.first { $0.communityId == communityId && $0.promptKey == promptKey }
    }

    func saveResponse(_ response: CommunityResponse) {
        if let index = responses.firstIndex(where: { $0.id == response.id }) {
            responses[index] = response
        } else {
            responses.append(response)
        }
    }

    func deleteResponse(communityId: String, promptKey: String) {
        responses.removeAll { $0.communityId == communityId && $0.promptKey == promptKey }
    }
}
