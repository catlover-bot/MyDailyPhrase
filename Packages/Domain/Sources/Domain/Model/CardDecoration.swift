import Foundation

public enum CardDecorationRarity: String, Codable, CaseIterable, Sendable {
    case common
    case rare
    case epic
    case legendary
}

public struct CardDecoration: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rarity: CardDecorationRarity
    public let weight: Int   // 抽選重み（大きいほど出やすい）

    public init(id: String, name: String, rarity: CardDecorationRarity, weight: Int) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.weight = max(0, weight)
    }
}
