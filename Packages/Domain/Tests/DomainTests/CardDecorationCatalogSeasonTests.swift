import Testing
@testable import Domain

@Suite("CardDecorationCatalog season rewards")
struct CardDecorationCatalogSeasonTests {

    @Test("シーズン限定デコはガチャ排出プールに含まれない")
    func seasonRewardsAreExcludedFromPool() {
        let poolIds = Set(CardDecorationCatalog.pool.map(\.id))
        for id in CardDecorationCatalog.seasonExclusiveIDs {
            #expect(!poolIds.contains(id))
            #expect(CardDecorationCatalog.byId(id)?.weight == 0)
        }
    }

    @Test("tier別シーズン報酬候補は限定デコのみ")
    func seasonCandidatesAreLimitedOnly() {
        let tiers = ["bronze", "silver", "gold"]
        for tier in tiers {
            let candidates = CardDecorationCatalog.seasonRewardCandidates(tierRaw: tier)
            #expect(!candidates.isEmpty)
            for item in candidates {
                #expect(CardDecorationCatalog.isSeasonLimited(item.id))
            }
        }
    }
}
