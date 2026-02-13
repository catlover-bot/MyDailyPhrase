import Foundation

public enum CardDecorationCatalog {
    // NOTE: id は UserProfile.selectedDecorationId / ownedDecorationIds と一致させる
    public static let classicId = "classic"

    public static let all: [CardDecoration] = [
        // classic は標準（排出対象から外す）
        CardDecoration(id: classicId, name: "Classic", rarity: .common, weight: 0),

        // Common
        CardDecoration(id: "paper",  name: "Paper",  rarity: .common, weight: 60),
        CardDecoration(id: "noir",   name: "Noir",   rarity: .common, weight: 60),

        // Rare
        CardDecoration(id: "sakura", name: "Sakura", rarity: .rare, weight: 25),
        CardDecoration(id: "neon",   name: "Neon",   rarity: .rare, weight: 25),

        // Epic
        CardDecoration(id: "aurora", name: "Aurora", rarity: .epic, weight: 12),
        CardDecoration(id: "glitch", name: "Glitch", rarity: .epic, weight: 12),

        // Legendary
        CardDecoration(id: "gold",   name: "Gold",   rarity: .legendary, weight: 3),
    ]

    // ガチャ排出対象（classic除外）
    public static let pool: [CardDecoration] = all.filter { $0.id != classicId && $0.weight > 0 }

    public static func byId(_ id: String) -> CardDecoration? {
        all.first { $0.id == id }
    }
}
