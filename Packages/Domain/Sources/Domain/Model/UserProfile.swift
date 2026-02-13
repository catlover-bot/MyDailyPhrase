import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public let userId: String
    public var displayName: String

    // ===== Card Decoration / Gacha =====
    public var selectedDecorationId: String

    /// 互換用：古い実装との橋渡し（UIで “所持” 判定に使っている箇所があれば残す）
    public var ownedDecorationIds: [String]

    /// ✅ 新: 所持数（ここを正にすることで、アイテム管理が強くなる）
    public var ownedDecorationCounts: [String: Int]

    /// ✅ 新: 重複時に貯まる欠片（後で交換所に使う）
    public var decorationShards: Int

    /// ✅ 新: 天井カウント（Legendary でリセット）
    public var pityCount: Int

    public var gachaTickets: Int
    public var lastFreeTicketDateKey: String?

    public init(
        userId: String,
        displayName: String,
        selectedDecorationId: String = CardDecorationCatalog.classicId,
        ownedDecorationIds: [String] = [CardDecorationCatalog.classicId],
        ownedDecorationCounts: [String: Int] = [CardDecorationCatalog.classicId: 1],
        decorationShards: Int = 0,
        pityCount: Int = 0,
        gachaTickets: Int = 0,
        lastFreeTicketDateKey: String? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.selectedDecorationId = selectedDecorationId
        self.ownedDecorationIds = ownedDecorationIds
        self.ownedDecorationCounts = ownedDecorationCounts
        self.decorationShards = decorationShards
        self.pityCount = pityCount
        self.gachaTickets = gachaTickets
        self.lastFreeTicketDateKey = lastFreeTicketDateKey

        self.normalize()
    }

    // 既存保存データ互換
    private enum CodingKeys: String, CodingKey {
        case userId, displayName
        case selectedDecorationId
        case ownedDecorationIds
        case ownedDecorationCounts
        case decorationShards
        case pityCount
        case gachaTickets
        case lastFreeTicketDateKey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.userId = try c.decode(String.self, forKey: .userId)
        self.displayName = try c.decode(String.self, forKey: .displayName)

        self.selectedDecorationId = try c.decodeIfPresent(String.self, forKey: .selectedDecorationId) ?? CardDecorationCatalog.classicId
        self.ownedDecorationIds = try c.decodeIfPresent([String].self, forKey: .ownedDecorationIds) ?? [CardDecorationCatalog.classicId]

        // ✅ 新フィールドが無い古いJSONは ownedDecorationIds から復元
        self.ownedDecorationCounts = try c.decodeIfPresent([String: Int].self, forKey: .ownedDecorationCounts)
            ?? Dictionary(uniqueKeysWithValues: self.ownedDecorationIds.map { ($0, 1) })

        self.decorationShards = try c.decodeIfPresent(Int.self, forKey: .decorationShards) ?? 0
        self.pityCount = try c.decodeIfPresent(Int.self, forKey: .pityCount) ?? 0
        self.gachaTickets = try c.decodeIfPresent(Int.self, forKey: .gachaTickets) ?? 0
        self.lastFreeTicketDateKey = try c.decodeIfPresent(String.self, forKey: .lastFreeTicketDateKey)

        self.normalize()
    }

    /// データ整合性を担保
    public mutating func normalize() {
        // classic は必ず所持
        if (ownedDecorationCounts[CardDecorationCatalog.classicId] ?? 0) <= 0 {
            ownedDecorationCounts[CardDecorationCatalog.classicId] = 1
        }
        // ownedDecorationIds は counts から再生成（互換維持）
        ownedDecorationIds = ownedDecorationCounts
            .filter { $0.value > 0 }
            .map { $0.key }

        if ownedDecorationIds.isEmpty {
            ownedDecorationIds = [CardDecorationCatalog.classicId]
        }

        // selected は所持に寄せる
        if (ownedDecorationCounts[selectedDecorationId] ?? 0) <= 0 {
            selectedDecorationId = CardDecorationCatalog.classicId
        }

        decorationShards = max(0, decorationShards)
        pityCount = max(0, pityCount)
        gachaTickets = max(0, gachaTickets)
    }
}
