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
