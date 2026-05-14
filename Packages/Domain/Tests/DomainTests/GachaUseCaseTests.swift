import Foundation
import Testing
@testable import Domain

@Suite("Gacha UseCases")
struct GachaUseCaseTests {

    @Test("チケット不足時は抽選結果が空で状態不変")
    func drawWithInsufficientTickets() {
        let repo = InMemoryUserProfileRepository()
        let initial = UserProfile(
            userId: "u-insufficient",
            displayName: "tester",
            selectedDecorationId: CardDecorationCatalog.classicId,
            ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
            decorationShards: 5,
            pityCount: 7,
            gachaTickets: 3
        )
        repo.saveMyProfile(initial)

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-insufficient" })
        let draw = DrawDecorationGachaUseCase(get: get, update: update, pityThreshold: 80)

        let summary = draw(count: 10)
        let after = get()

        #expect(summary.drawn.isEmpty)
        #expect(summary.shardsGained == 0)
        #expect(summary.pityBefore == summary.pityAfter)
        #expect(summary.ticketsBefore == summary.ticketsAfter)
        #expect(after.gachaTickets == initial.gachaTickets)
        #expect(after.pityCount == initial.pityCount)
        #expect(after.decorationShards == initial.decorationShards)
    }

    @Test("無限チケット対象ユーザーは所持0でも抽選でき、消費しない")
    func drawWithUnlimitedTicketsUser() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-unlimited",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                decorationShards: 0,
                pityCount: 0,
                gachaTickets: 0
            )
        )

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-unlimited" })
        let draw = DrawDecorationGachaUseCase(
            get: get,
            update: update,
            pityThreshold: 80,
            hasUnlimitedTicketsForUserId: { $0 == "u-unlimited" }
        )

        let summary = draw(count: 1)
        let after = get()

        #expect(summary.drawn.count == 1)
        #expect(summary.ticketsBefore == 0)
        #expect(summary.ticketsAfter == 0)
        #expect(after.gachaTickets == 0)
    }

    @Test("天井直前はLEGENDARY確定")
    func hardPityGuaranteesLegendary() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-pity",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                decorationShards: 0,
                pityCount: 79,
                gachaTickets: 1
            )
        )

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-pity" })
        let draw = DrawDecorationGachaUseCase(get: get, update: update, pityThreshold: 80)

        let summary = draw(count: 1)
        let after = get()

        #expect(summary.drawn.count == 1)
        #expect(summary.drawn[0].rarity == .legendary)
        #expect(summary.pityBefore == 79)
        #expect(summary.pityAfter == 0)
        #expect(after.pityCount == 0)
        #expect(after.gachaTickets == 0)
    }

    @Test("10連は最低1つRARE以上が含まれる")
    func tenPullGuaranteesRareOrBetter() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-ten",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                decorationShards: 0,
                pityCount: 0,
                gachaTickets: 10
            )
        )

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-ten" })
        let draw = DrawDecorationGachaUseCase(get: get, update: update, pityThreshold: 80)

        let summary = draw(count: 10)
        let after = get()

        #expect(summary.drawn.count == 10)
        #expect(summary.drawn.contains(where: { $0.rarity != .common }))
        #expect(summary.ticketsBefore == 10)
        #expect(summary.ticketsAfter == 0)
        #expect(after.gachaTickets == 0)
    }

    @Test("抽選後も現在の装備は維持される")
    func selectedDecorationStaysUnchangedAfterDraw() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-best",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                decorationShards: 0,
                pityCount: 0,
                gachaTickets: 10
            )
        )

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-best" })
        let draw = DrawDecorationGachaUseCase(get: get, update: update, pityThreshold: 80)

        let summary = draw(count: 10)
        let after = get()

        #expect(!summary.drawn.isEmpty)
        #expect(after.selectedDecorationId == CardDecorationCatalog.classicId)
    }

    @Test("無料券付与は同日2回目で付与されない")
    func grantDailyTicketIsIdempotentInSameDay() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-daily",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                decorationShards: 0,
                pityCount: 0,
                gachaTickets: 0
            )
        )

        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-daily" })
        let grant = GrantDailyFreeTicketUseCase(get: get, update: update, timeZone: .current)

        let first = grant()
        let second = grant()
        let after = get()

        #expect(first == true)
        #expect(second == false)
        #expect(after.gachaTickets == 1)
        #expect(after.lastFreeTicketDateKey != nil)
    }

    @Test("新規獲得は所持レコードに保存される")
    func drawStoresOwnedDecorationRecord() {
        let repo = InMemoryUserProfileRepository()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-record",
                displayName: "tester",
                selectedDecorationId: CardDecorationCatalog.classicId,
                ownedDecorationCounts: [CardDecorationCatalog.classicId: 1],
                ownedDecorationRecords: [
                    CardDecorationCatalog.classicId: OwnedDecorationRecord(
                        acquisitionDate: .distantPast,
                        source: .defaultItem,
                        count: 1
                    )
                ],
                gachaTickets: 1
            )
        )

        let drawDate = Date(timeIntervalSince1970: 1_700_000_000)
        let get = GetMyProfileUseCase(repo: repo)
        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-record" })
        let draw = DrawDecorationGachaUseCase(
            get: get,
            update: update,
            pityThreshold: 80,
            nowProvider: { drawDate }
        )

        let summary = draw(count: 1)
        let drawnId = try! #require(summary.drawn.first?.id)
        let after = get()
        let record = after.ownedDecorationRecords[drawnId]

        #expect(record?.count == after.ownedDecorationCounts[drawnId])
        #expect(record?.acquisitionDate == drawDate || record?.source == .defaultItem)
        if drawnId != CardDecorationCatalog.classicId {
            #expect(record?.source == .freeGacha)
        }
    }

    @Test("重複時の欠片変換はレアリティごとに固定")
    func duplicateShardRewardsAreStable() {
        #expect(GachaOddsPolicy.duplicateShardReward(for: .common) == 1)
        #expect(GachaOddsPolicy.duplicateShardReward(for: .rare) == 3)
        #expect(GachaOddsPolicy.duplicateShardReward(for: .epic) == 10)
        #expect(GachaOddsPolicy.duplicateShardReward(for: .legendary) == 30)
    }

    @Test("表示用の提供割合は抽選プールの重みと一致する")
    func rarityOddsUseSameSourceAsDrawPool() {
        let pool = CardDecorationCatalog.pool
        let totalWeight = Double(pool.map(\.weight).reduce(0, +))
        let commonWeight = Double(pool.filter { $0.rarity == .common }.map(\.weight).reduce(0, +))
        let legendaryWeight = Double(pool.filter { $0.rarity == .legendary }.map(\.weight).reduce(0, +))

        let rows = GachaOddsPolicy.rarityOdds(pool: pool)
        let common = rows.first { $0.rarity == .common }
        let legendary = rows.first { $0.rarity == .legendary }

        #expect(common?.probability == commonWeight / totalWeight)
        #expect(legendary?.probability == legendaryWeight / totalWeight)
        #expect(rows.map(\.probability).reduce(0, +) == 1.0)
    }
}

private final class InMemoryUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var profile: UserProfile?

    func getMyProfile() -> UserProfile? {
        withLock { profile }
    }

    func saveMyProfile(_ profile: UserProfile) {
        withLock {
            self.profile = profile
        }
    }

    @discardableResult
    func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        withLock {
            var p = profile ?? makeIfMissing()
            mutate(&p)
            profile = p
            return p
        }
    }

    @inline(__always)
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
