import Foundation
import Testing
import Domain
@testable import Data

@Suite("AppGroupUserProfileRepository")
struct AppGroupUserProfileRepositoryTests {
    private let primaryKey = "MyDailyPhrase.profile.v1"
    private let backupKey = "MyDailyPhrase.profile.backup.v1"
    private let corruptKey = "MyDailyPhrase.profile.corrupt.v1"
    private let recoveryKey = "MyDailyPhrase.profile.recoveredAt.v1"

    @Test("primary破損時はbackupから復旧する")
    func recoversFromBackupWhenPrimaryCorrupt() throws {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("suiteNameが作成できませんでした: \(suite)")
            return
        }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        let base = UserProfile(
            userId: "u-recovery",
            displayName: "tester",
            selectedDecorationId: "paper",
            ownedDecorationCounts: [
                CardDecorationCatalog.classicId: 1,
                "paper": 1
            ],
            gachaTickets: 5
        )

        repo.saveMyProfile(base)
        let backupData = defaults.data(forKey: backupKey)
        #expect(backupData != nil)

        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: primaryKey)

        let recovered = repo.getMyProfile()
        #expect(recovered?.userId == base.userId)
        #expect(recovered?.selectedDecorationId == base.selectedDecorationId)
        #expect(recovered?.gachaTickets == base.gachaTickets)

        let restoredPrimary = defaults.data(forKey: primaryKey)
        #expect(restoredPrimary == backupData)
        #expect(defaults.data(forKey: corruptKey) != nil)
        #expect(defaults.double(forKey: recoveryKey) > 0)
    }

    @Test("正常保存時はcorruptマーカーをクリアする")
    func saveClearsCorruptMarker() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("suiteNameが作成できませんでした: \(suite)")
            return
        }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        defaults.set(Data([0x10, 0x20]), forKey: corruptKey)

        repo.saveMyProfile(
            UserProfile(
                userId: "u-clean",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1]
            )
        )

        #expect(defaults.data(forKey: corruptKey) == nil)
        #expect(defaults.data(forKey: primaryKey) != nil)
        #expect(defaults.data(forKey: backupKey) != nil)
    }

    @Test("保存データが無い場合はnilを返す")
    func returnsNilWhenNoProfileData() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        #expect(repo.getMyProfile() == nil)
    }

    @Test("owned records and equipped set round-trip through persistence")
    func persistsOwnedRecordsAndEquippedSet() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupUserProfileRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        let profile = UserProfile(
            userId: "u-rich",
            displayName: "tester",
            selectedDecorationId: "gold",
            equippedDecorationSet: EquippedDecorationSet(primaryDecorationId: "gold"),
            ownedDecorationCounts: [
                CardDecorationCatalog.classicId: 1,
                "gold": 2
            ],
            ownedDecorationRecords: [
                CardDecorationCatalog.classicId: OwnedDecorationRecord(
                    acquisitionDate: .distantPast,
                    source: .defaultItem,
                    count: 1
                ),
                "gold": OwnedDecorationRecord(
                    acquisitionDate: Date(timeIntervalSince1970: 1234),
                    source: .freeGacha,
                    count: 2
                )
            ]
        )

        repo.saveMyProfile(profile)
        let recovered = repo.getMyProfile()

        #expect(recovered?.selectedDecorationId == "gold")
        #expect(recovered?.equippedDecorationSet.primaryDecorationId == "gold")
        #expect(recovered?.ownedDecorationRecords["gold"]?.count == 2)
        #expect(recovered?.ownedDecorationRecords["gold"]?.source == .freeGacha)
    }

    private func makeSuiteName() -> String {
        "group.MyDailyPhrase.tests.\(UUID().uuidString)"
    }

    private func cleanupSuite(_ suite: String) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}

@Suite("AppGroupCommunityTemplateRepository")
struct AppGroupCommunityTemplateRepositoryTests {
    @Test("custom prompt seeds are stored locally")
    func storesCustomPromptSeeds() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupCommunityTemplateRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        var community = CommunityTemplate(
            id: "creator.games.rpg",
            name: "RPG好きの部屋",
            description: "旅や仲間を語る部屋",
            category: .games,
            emoji: "🗺️",
            createdAt: Date(timeIntervalSince1970: 1000),
            creatorDisplayName: "Me",
            creatorId: "me",
            visibility: .inviteOnly,
            promptPolicy: CommunityPromptPolicy(),
            promptSchedule: .weekly,
            promptPacks: ["retro"],
            themeDecorationId: "retro",
            allowedTags: ["games", "rpg"],
            blockedWords: ["spoiler"],
            isOfficialPreset: false,
            requiresCreatorPassToCreate: true,
            isJoined: true,
            joinedAt: Date(timeIntervalSince1970: 1001),
            customPromptSeeds: ["好きなジョブを一言で。", "また旅したい街は？"],
            pinnedNextPromptText: "今週また会いたい仲間は？"
        )
        community.normalize()

        repo.saveCommunity(community)
        let loaded = repo.community(id: "creator.games.rpg")

        #expect(loaded?.customPromptSeeds.count == 2)
        #expect(loaded?.pinnedNextPromptText == "今週また会いたい仲間は？")
        #expect(loaded?.isJoined == true)
    }

    @Test("community join state and response round-trip through persistence")
    func persistsJoinStateAndResponse() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupCommunityTemplateRepository(appGroupID: suite, forceSynchronizeOnWrite: true)
        let community = CommunityTemplate(
            id: "official.games.general",
            name: "ゲーム好きの部屋",
            description: "ゲームの一言部屋",
            category: .games,
            emoji: "🎮",
            createdAt: Date(timeIntervalSince1970: 1000),
            creatorDisplayName: "official",
            creatorId: "official",
            visibility: .inviteOnly,
            promptPolicy: CommunityPromptPolicy(),
            promptSchedule: .daily,
            promptPacks: [],
            themeDecorationId: "arcade",
            allowedTags: ["games"],
            blockedWords: [],
            isOfficialPreset: true,
            requiresCreatorPassToCreate: false,
            isJoined: false
        )

        repo.saveCommunity(community)
        repo.setJoined(true, communityId: community.id, joinedAt: Date(timeIntervalSince1970: 2000))
        repo.saveResponse(
            CommunityResponse(
                communityId: community.id,
                promptKey: "20260514",
                promptText: "最近いちばん時間を忘れたゲームは？",
                answer: "最近はRPGに夢中",
                updatedAt: Date(timeIntervalSince1970: 2001)
            )
        )

        let loaded = repo.community(id: community.id)
        let response = repo.response(communityId: community.id, promptKey: "20260514")

        #expect(loaded?.isJoined == true)
        #expect(loaded?.joinedAt == Date(timeIntervalSince1970: 2000))
        #expect(response?.answer == "最近はRPGに夢中")
    }

    private func makeSuiteName() -> String {
        "group.MyDailyPhrase.community.tests.\(UUID().uuidString)"
    }

    private func cleanupSuite(_ suite: String) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}
