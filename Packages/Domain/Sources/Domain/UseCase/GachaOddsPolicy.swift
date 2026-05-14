import Foundation

public struct GachaRarityOddsRow: Equatable, Sendable {
    public let rarity: CardDecorationRarity
    public let itemCount: Int
    public let probability: Double

    public init(rarity: CardDecorationRarity, itemCount: Int, probability: Double) {
        self.rarity = rarity
        self.itemCount = itemCount
        self.probability = probability
    }
}

public struct GachaItemOddsRow: Equatable, Sendable {
    public let item: CardDecoration
    public let probability: Double
    public let isFeatured: Bool

    public init(item: CardDecoration, probability: Double, isFeatured: Bool) {
        self.item = item
        self.probability = probability
        self.isFeatured = isFeatured
    }
}

public enum GachaOddsPolicy {
    public static func legendaryBoostMultiplier(pityCount: Int) -> Double {
        if pityCount < 60 { return 1.0 }
        let t = min(1.0, Double(pityCount - 60) / 19.0)
        return 1.0 + 9.0 * t
    }

    public static func duplicateShardReward(for rarity: CardDecorationRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 3
        case .epic: return 10
        case .legendary: return 30
        }
    }

    public static func rarityOdds(
        pool: [CardDecoration] = CardDecorationCatalog.pool,
        pickupMultipliers: [String: Double] = [:],
        pityCount: Int = 0,
        restrictRarePlus: Bool = false
    ) -> [GachaRarityOddsRow] {
        let effectivePool = filteredPool(
            from: pool,
            pickupMultipliers: pickupMultipliers,
            pityCount: pityCount,
            restrictRarePlus: restrictRarePlus
        )
        let total = max(0.000_000_1, effectivePool.map(\.1).reduce(0.0, +))

        return CardDecorationRarity.allCases.map { rarity in
            let rows = effectivePool.filter { $0.0.rarity == rarity }
            let weight = rows.map(\.1).reduce(0.0, +)
            return GachaRarityOddsRow(
                rarity: rarity,
                itemCount: rows.count,
                probability: weight / total
            )
        }
    }

    public static func itemOdds(
        pool: [CardDecoration] = CardDecorationCatalog.pool,
        pickupMultipliers: [String: Double] = [:],
        pityCount: Int = 0,
        restrictRarePlus: Bool = false
    ) -> [GachaItemOddsRow] {
        let effectivePool = filteredPool(
            from: pool,
            pickupMultipliers: pickupMultipliers,
            pityCount: pityCount,
            restrictRarePlus: restrictRarePlus
        )
        let total = max(0.000_000_1, effectivePool.map(\.1).reduce(0.0, +))

        return effectivePool.map { item, weight in
            GachaItemOddsRow(
                item: item,
                probability: weight / total,
                isFeatured: pickupMultipliers[item.id] != nil
            )
        }
    }

    private static func filteredPool(
        from pool: [CardDecoration],
        pickupMultipliers: [String: Double],
        pityCount: Int,
        restrictRarePlus: Bool
    ) -> [(CardDecoration, Double)] {
        let candidates = pool
            .filter { $0.weight > 0 }
            .filter { restrictRarePlus ? $0.rarity != .common : true }

        let boost = legendaryBoostMultiplier(pityCount: pityCount)
        return candidates.map { item in
            let pickup = max(0.0, pickupMultipliers[item.id] ?? 1.0)
            let pity = item.rarity == .legendary ? boost : 1.0
            return (item, Double(item.weight) * pickup * pity)
        }
    }
}
