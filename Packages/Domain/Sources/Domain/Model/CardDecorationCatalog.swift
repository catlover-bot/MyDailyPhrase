import Foundation

public enum CardDecorationCatalog {
    // NOTE: id は UserProfile.selectedDecorationId / ownedDecorationIds と一致させる
    public static let classicId = "classic"

    public static let all: [CardDecoration] = [
        // classic は標準（排出対象から外す）
        CardDecoration(id: classicId, name: "Classic", rarity: .common, weight: 0),

        // Common
        CardDecoration(id: "paper",     name: "Paper",     rarity: .common, weight: 60),
        CardDecoration(id: "noir",      name: "Noir",      rarity: .common, weight: 60),
        CardDecoration(id: "linen",     name: "Linen",     rarity: .common, weight: 42),
        CardDecoration(id: "graphite",  name: "Graphite",  rarity: .common, weight: 42),
        CardDecoration(id: "mint",      name: "Mint",      rarity: .common, weight: 42),
        CardDecoration(id: "sunset",    name: "Sunset",    rarity: .common, weight: 42),
        CardDecoration(id: "cloud",     name: "Cloud",     rarity: .common, weight: 42),
        CardDecoration(id: "retro",     name: "Retro",     rarity: .common, weight: 42),
        CardDecoration(id: "cotton",    name: "Cotton",    rarity: .common, weight: 36),
        CardDecoration(id: "denim",     name: "Denim",     rarity: .common, weight: 36),
        CardDecoration(id: "pearl",     name: "Pearl",     rarity: .common, weight: 36),
        CardDecoration(id: "sage",      name: "Sage",      rarity: .common, weight: 36),

        // Rare
        CardDecoration(id: "sakura",    name: "Sakura",    rarity: .rare, weight: 25),
        CardDecoration(id: "neon",      name: "Neon",      rarity: .rare, weight: 25),
        CardDecoration(id: "marine",    name: "Marine",    rarity: .rare, weight: 18),
        CardDecoration(id: "amber",     name: "Amber",     rarity: .rare, weight: 18),
        CardDecoration(id: "forest",    name: "Forest",    rarity: .rare, weight: 18),
        CardDecoration(id: "plaid",     name: "Plaid",     rarity: .rare, weight: 18),
        CardDecoration(id: "inkdrop",   name: "Inkdrop",   rarity: .rare, weight: 18),
        CardDecoration(id: "moonlit",   name: "Moonlit",   rarity: .rare, weight: 18),
        CardDecoration(id: "ruby",      name: "Ruby",      rarity: .rare, weight: 16),
        CardDecoration(id: "teal",      name: "Teal",      rarity: .rare, weight: 16),
        CardDecoration(id: "fog",       name: "Fog",       rarity: .rare, weight: 16),
        CardDecoration(id: "brick",     name: "Brick",     rarity: .rare, weight: 16),

        // Epic
        CardDecoration(id: "aurora",    name: "Aurora",    rarity: .epic, weight: 12),
        CardDecoration(id: "glitch",    name: "Glitch",    rarity: .epic, weight: 12),
        CardDecoration(id: "hologram",  name: "Hologram",  rarity: .epic, weight: 8),
        CardDecoration(id: "crystal",   name: "Crystal",   rarity: .epic, weight: 8),
        CardDecoration(id: "stardust",  name: "Stardust",  rarity: .epic, weight: 8),
        CardDecoration(id: "matrix",    name: "Matrix",    rarity: .epic, weight: 8),
        CardDecoration(id: "volt",      name: "Volt",      rarity: .epic, weight: 8),
        CardDecoration(id: "obsidian",  name: "Obsidian",  rarity: .epic, weight: 8),
        CardDecoration(id: "nebula",    name: "Nebula",    rarity: .epic, weight: 7),
        CardDecoration(id: "arcade",    name: "Arcade",    rarity: .epic, weight: 7),
        CardDecoration(id: "sonar",     name: "Sonar",     rarity: .epic, weight: 7),
        CardDecoration(id: "starlight", name: "Starlight", rarity: .epic, weight: 8),
        CardDecoration(id: "ocean",     name: "Ocean",     rarity: .epic, weight: 8),
        CardDecoration(id: "comet",     name: "Comet",     rarity: .epic, weight: 7),

        // Legendary
        CardDecoration(id: "gold",      name: "Gold",      rarity: .legendary, weight: 3),
        CardDecoration(id: "royal",     name: "Royal",     rarity: .legendary, weight: 1),
        CardDecoration(id: "phoenix",   name: "Phoenix",   rarity: .legendary, weight: 1),
        CardDecoration(id: "eclipse",   name: "Eclipse",   rarity: .legendary, weight: 1),
        CardDecoration(id: "prism",     name: "Prism",     rarity: .legendary, weight: 1),
        CardDecoration(id: "celestial", name: "Celestial", rarity: .legendary, weight: 1),
        CardDecoration(id: "auric",     name: "Auric",     rarity: .legendary, weight: 1),
        CardDecoration(id: "zenith",    name: "Zenith",    rarity: .legendary, weight: 1),
        CardDecoration(id: "nova",      name: "Nova",      rarity: .legendary, weight: 1),
        CardDecoration(id: "galaxy",      name: "Galaxy",      rarity: .legendary, weight: 1),
        CardDecoration(id: "singularity", name: "Singularity", rarity: .legendary, weight: 1),

        // Season limited rewards (週次報酬専用 / 排出しない)
        CardDecoration(id: "season_bronze_sprout", name: "Sprout Emblem",  rarity: .rare,      weight: 0),
        CardDecoration(id: "season_bronze_ripple", name: "Ripple Emblem",  rarity: .rare,      weight: 0),
        CardDecoration(id: "season_bronze_ember",  name: "Ember Emblem",   rarity: .rare,      weight: 0),
        CardDecoration(id: "season_silver_comet",  name: "Comet Crest",    rarity: .epic,      weight: 0),
        CardDecoration(id: "season_silver_mirror", name: "Mirror Crest",   rarity: .epic,      weight: 0),
        CardDecoration(id: "season_silver_tidal",  name: "Tidal Crest",    rarity: .epic,      weight: 0),
        CardDecoration(id: "season_gold_crown",    name: "Crown Sigil",    rarity: .legendary, weight: 0),
        CardDecoration(id: "season_gold_halo",     name: "Halo Sigil",     rarity: .legendary, weight: 0),
        CardDecoration(id: "season_gold_eternal",  name: "Eternal Sigil",  rarity: .legendary, weight: 0),
    ]

    public static let seasonRewardIDsByTier: [String: [String]] = [
        "bronze": [
            "season_bronze_sprout",
            "season_bronze_ripple",
            "season_bronze_ember"
        ],
        "silver": [
            "season_silver_comet",
            "season_silver_mirror",
            "season_silver_tidal"
        ],
        "gold": [
            "season_gold_crown",
            "season_gold_halo",
            "season_gold_eternal"
        ]
    ]

    // ガチャ排出対象（classic除外）
    public static let pool: [CardDecoration] = all.filter { $0.id != classicId && $0.weight > 0 }

    public static let seasonExclusiveIDs: Set<String> = Set(
        seasonRewardIDsByTier.values.flatMap { $0 }
    )

    public static func byId(_ id: String) -> CardDecoration? {
        all.first { $0.id == id }
    }

    public static func isSeasonLimited(_ id: String) -> Bool {
        seasonExclusiveIDs.contains(id)
    }

    public static func seasonRewardCandidates(tierRaw: String) -> [CardDecoration] {
        let key = tierRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ids = seasonRewardIDsByTier[key] ?? []
        return ids.compactMap(byId)
    }
}
