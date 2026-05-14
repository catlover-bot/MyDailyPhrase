import Foundation

public struct GachaDrawSummary: Sendable, Equatable {
    public let drawn: [CardDecoration]
    public let newIds: Set<String>
    public let shardsGained: Int
    public let ticketsBefore: Int
    public let ticketsAfter: Int
    public let pityBefore: Int
    public let pityAfter: Int
}

public struct DrawDecorationGachaUseCase: Sendable {
    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase
    private let hasUnlimitedTicketsForUserId: @Sendable (String) -> Bool
    private let nowProvider: @Sendable () -> Date

    /// 天井（Legendary確定までの上限）
    private let pityThreshold: Int

    public init(
        get: GetMyProfileUseCase,
        update: UpdateMyProfileUseCase,
        pityThreshold: Int = 80,
        hasUnlimitedTicketsForUserId: @escaping @Sendable (String) -> Bool = { _ in false },
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.get = get
        self.update = update
        self.pityThreshold = max(1, pityThreshold)
        self.hasUnlimitedTicketsForUserId = hasUnlimitedTicketsForUserId
        self.nowProvider = nowProvider
    }

    /// ✅ pickupMultipliers:
    ///   ["sakura": 1.8, "glitch": 2.0] のように「重み倍率」を指定
    @discardableResult
    public func callAsFunction(
        count: Int,
        pickupMultipliers: [String: Double] = [:]
    ) -> GachaDrawSummary {
        let n = max(1, count)
        var p = get()
        let hasUnlimitedTickets = hasUnlimitedTicketsForUserId(p.userId)

        let ticketsBefore = p.gachaTickets
        let pityBefore = p.pityCount

        guard hasUnlimitedTickets || p.gachaTickets >= n else {
            return GachaDrawSummary(
                drawn: [],
                newIds: [],
                shardsGained: 0,
                ticketsBefore: ticketsBefore,
                ticketsAfter: ticketsBefore,
                pityBefore: pityBefore,
                pityAfter: pityBefore
            )
        }

        var drawn: [CardDecoration] = []
        var newIds = Set<String>()
        var shards = 0
        var hasRarePlus = false

        for i in 0..<n {
            // ✅ 天井直前は確定でLegendary（ピックアップ倍率も反映）
            if p.pityCount >= (pityThreshold - 1) {
                let legendary = pickWeighted(
                    from: CardDecorationCatalog.pool.filter { $0.rarity == .legendary },
                    pityCount: p.pityCount,
                    pickupMultipliers: pickupMultipliers
                )
                p.pityCount = 0

                drawn.append(legendary)
                applyGain(item: legendary, profile: &p, newIds: &newIds, shards: &shards)
                hasRarePlus = true
                continue
            }

            // ✅ 10連保証：最後の1回、まだRare+が出ていなければ pool を Rare+ に限定
            let restrictRarePlus =
                (n >= 10) && (i == n - 1) && (!hasRarePlus)

            let basePool = CardDecorationCatalog.pool
            let pool = restrictRarePlus ? basePool.filter { $0.rarity != .common } : basePool

            // ✅ ソフト天井：pityが進むほどLegendary重みを上げる（確定前に“出やすくなる感”）
            let item = pickWeighted(
                from: pool,
                pityCount: p.pityCount,
                pickupMultipliers: pickupMultipliers
            )

            // pity更新：Legendaryならリセット、それ以外は+1
            if item.rarity == .legendary {
                p.pityCount = 0
            } else {
                p.pityCount += 1
            }

            drawn.append(item)
            applyGain(item: item, profile: &p, newIds: &newIds, shards: &shards)
            if item.rarity != .common { hasRarePlus = true }
        }

        // チケット消費（無限対象ユーザーは消費しない）
        if !hasUnlimitedTickets {
            p.gachaTickets = max(0, p.gachaTickets - n)
        }

        p.normalize()

        let ticketsAfter = p.gachaTickets
        let pityAfter = p.pityCount

        _ = update(
            selectedDecorationId: p.selectedDecorationId,
            ownedDecorationCounts: p.ownedDecorationCounts,
            ownedDecorationRecords: p.ownedDecorationRecords,
            decorationShards: p.decorationShards,
            pityCount: p.pityCount,
            gachaTickets: p.gachaTickets
        )

        return GachaDrawSummary(
            drawn: drawn,
            newIds: newIds,
            shardsGained: shards,
            ticketsBefore: ticketsBefore,
            ticketsAfter: ticketsAfter,
            pityBefore: pityBefore,
            pityAfter: pityAfter
        )
    }

    // MARK: - Gain / Duplicate -> Shards

    private func applyGain(
        item: CardDecoration,
        profile p: inout UserProfile,
        newIds: inout Set<String>,
        shards: inout Int
    ) {
        let prev = p.ownedDecorationCounts[item.id] ?? 0
        p.ownedDecorationCounts[item.id] = prev + 1

        if prev == 0 {
            newIds.insert(item.id)
            p.ownedDecorationRecords[item.id] = OwnedDecorationRecord(
                acquisitionDate: nowProvider(),
                source: .freeGacha,
                count: 1
            )
        } else {
            let add = duplicateShard(for: item.rarity)
            p.decorationShards += add
            shards += add
            let existing = p.ownedDecorationRecords[item.id]
            p.ownedDecorationRecords[item.id] = OwnedDecorationRecord(
                acquisitionDate: existing?.acquisitionDate ?? nowProvider(),
                source: existing?.source ?? .freeGacha,
                count: prev + 1
            )
        }
    }

    private func duplicateShard(for rarity: CardDecorationRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 3
        case .epic: return 10
        case .legendary: return 30
        }
    }

    // MARK: - RNG (weighted + soft pity + pickup)

    private func legendaryBoostMultiplier(pityCount: Int) -> Double {
        // 例：60回を超えたあたりからLegendaryが徐々に出やすくなる
        // (60..79) で 1.0 -> 10.0 へ
        if pityCount < 60 { return 1.0 }
        let t = min(1.0, Double(pityCount - 60) / 19.0) // 60..79
        return 1.0 + 9.0 * t
    }

    private func pickWeighted(
        from pool: [CardDecoration],
        pityCount: Int,
        pickupMultipliers: [String: Double]
    ) -> CardDecoration {
        let valid = pool.filter { $0.weight > 0 }
        guard !valid.isEmpty else {
            return CardDecoration(id: CardDecorationCatalog.classicId, name: "Classic", rarity: .common, weight: 0)
        }

        let lgBoost = legendaryBoostMultiplier(pityCount: pityCount)

        // Double重みでサンプル
        let weights: [Double] = valid.map { x in
            let base = Double(x.weight)
            let pickup = max(0.0, pickupMultipliers[x.id] ?? 1.0)
            let pity = (x.rarity == .legendary) ? lgBoost : 1.0
            return base * pickup * pity
        }

        let total = weights.reduce(0.0, +)
        if total <= 0 {
            return valid.last!
        }

        let r = Double.random(in: 0..<total)
        var acc = 0.0
        for (idx, w) in weights.enumerated() {
            acc += w
            if r < acc { return valid[idx] }
        }
        return valid.last!
    }
}
