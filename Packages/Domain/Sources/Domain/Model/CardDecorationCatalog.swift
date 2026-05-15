import Foundation

public enum CardDecorationCatalog {
    // NOTE: id は UserProfile.selectedDecorationId / ownedDecorationIds と一致させる
    public static let classicId = "classic"

    public static let all: [CardDecoration] = [
        // classic は標準（排出対象から外す）
        CardDecoration(id: classicId, name: "いつものカード", rarity: .common, weight: 0),

        // Common
        CardDecoration(id: "paper",     name: "やわらか紙面",   rarity: .common, weight: 60),
        CardDecoration(id: "noir",      name: "夜色ノート",     rarity: .common, weight: 60),
        CardDecoration(id: "linen",     name: "麻布ページ",     rarity: .common, weight: 42),
        CardDecoration(id: "graphite",  name: "鉛筆グレー",     rarity: .common, weight: 42),
        CardDecoration(id: "mint",      name: "ミントメモ",     rarity: .common, weight: 42),
        CardDecoration(id: "sunset",    name: "夕焼けノート",   rarity: .common, weight: 42),
        CardDecoration(id: "cloud",     name: "雲色ページ",     rarity: .common, weight: 42),
        CardDecoration(id: "retro",     name: "レトロ日記帳",   rarity: .common, weight: 42),
        CardDecoration(id: "cotton",    name: "コットンカード", rarity: .common, weight: 36),
        CardDecoration(id: "denim",     name: "デニムノート",   rarity: .common, weight: 36),
        CardDecoration(id: "pearl",     name: "パール余白",     rarity: .common, weight: 36),
        CardDecoration(id: "sage",      name: "セージ便箋",     rarity: .common, weight: 36),

        // Rare
        CardDecoration(id: "sakura",    name: "桜の日記帳",     rarity: .rare, weight: 25),
        CardDecoration(id: "neon",      name: "ネオンシティ",   rarity: .rare, weight: 25),
        CardDecoration(id: "marine",    name: "マリンブルー",   rarity: .rare, weight: 18),
        CardDecoration(id: "amber",     name: "琥珀メモ",       rarity: .rare, weight: 18),
        CardDecoration(id: "forest",    name: "森のカード",     rarity: .rare, weight: 18),
        CardDecoration(id: "plaid",     name: "チェック便箋",   rarity: .rare, weight: 18),
        CardDecoration(id: "inkdrop",   name: "インクしずく",   rarity: .rare, weight: 18),
        CardDecoration(id: "moonlit",   name: "月夜のページ",   rarity: .rare, weight: 18),
        CardDecoration(id: "ruby",      name: "ルビーノート",   rarity: .rare, weight: 16),
        CardDecoration(id: "teal",      name: "ティールレター", rarity: .rare, weight: 16),
        CardDecoration(id: "fog",       name: "霧の余白",       rarity: .rare, weight: 16),
        CardDecoration(id: "brick",     name: "レンガの縁",     rarity: .rare, weight: 16),

        // Epic
        CardDecoration(id: "aurora",    name: "オーロラログ",     rarity: .epic, weight: 12),
        CardDecoration(id: "glitch",    name: "グリッチカード",   rarity: .epic, weight: 12),
        CardDecoration(id: "hologram",  name: "ホログラム票",     rarity: .epic, weight: 8),
        CardDecoration(id: "crystal",   name: "クリスタル記録",   rarity: .epic, weight: 8),
        CardDecoration(id: "stardust",  name: "星屑レター",       rarity: .epic, weight: 8),
        CardDecoration(id: "matrix",    name: "マトリクス画面",   rarity: .epic, weight: 8),
        CardDecoration(id: "volt",      name: "ボルトライン",     rarity: .epic, weight: 8),
        CardDecoration(id: "obsidian",  name: "黒曜石フレーム",   rarity: .epic, weight: 8),
        CardDecoration(id: "nebula",    name: "星雲ジャーナル",   rarity: .epic, weight: 7),
        CardDecoration(id: "arcade",    name: "アーケード画面",   rarity: .epic, weight: 7),
        CardDecoration(id: "sonar",     name: "ソナーウェーブ",   rarity: .epic, weight: 7),
        CardDecoration(id: "starlight", name: "星明かりカード",   rarity: .epic, weight: 8),
        CardDecoration(id: "ocean",     name: "深海メモ",         rarity: .epic, weight: 8),
        CardDecoration(id: "comet",     name: "彗星ポスト",       rarity: .epic, weight: 7),

        // Legendary
        CardDecoration(id: "gold",      name: "王冠の紙面",       rarity: .legendary, weight: 3),
        CardDecoration(id: "royal",     name: "王室の記章",       rarity: .legendary, weight: 1),
        CardDecoration(id: "phoenix",   name: "不死鳥の余韻",     rarity: .legendary, weight: 1),
        CardDecoration(id: "eclipse",   name: "蝕のプロフィール", rarity: .legendary, weight: 1),
        CardDecoration(id: "prism",     name: "プリズムの祝福",   rarity: .legendary, weight: 1),
        CardDecoration(id: "celestial", name: "天球のことば",     rarity: .legendary, weight: 1),
        CardDecoration(id: "auric",     name: "金彩の一枚",       rarity: .legendary, weight: 1),
        CardDecoration(id: "zenith",    name: "天頂のカード",     rarity: .legendary, weight: 1),
        CardDecoration(id: "nova",      name: "新星の光",         rarity: .legendary, weight: 1),
        CardDecoration(id: "galaxy",    name: "銀河プロムナード", rarity: .legendary, weight: 1),
        CardDecoration(id: "singularity", name: "特異点レター",   rarity: .legendary, weight: 1),

        // Season limited rewards (週次報酬専用 / 排出しない)
        CardDecoration(id: "season_bronze_sprout", name: "若葉のしるし",   rarity: .rare,      weight: 0),
        CardDecoration(id: "season_bronze_ripple", name: "さざ波のしるし", rarity: .rare,      weight: 0),
        CardDecoration(id: "season_bronze_ember",  name: "残り火のしるし", rarity: .rare,      weight: 0),
        CardDecoration(id: "season_silver_comet",  name: "彗星の紋章",     rarity: .epic,      weight: 0),
        CardDecoration(id: "season_silver_mirror", name: "鏡面の紋章",     rarity: .epic,      weight: 0),
        CardDecoration(id: "season_silver_tidal",  name: "潮騒の紋章",     rarity: .epic,      weight: 0),
        CardDecoration(id: "season_gold_crown",    name: "王冠の印",       rarity: .legendary, weight: 0),
        CardDecoration(id: "season_gold_halo",     name: "光輪の印",       rarity: .legendary, weight: 0),
        CardDecoration(id: "season_gold_eternal",  name: "永遠の印",       rarity: .legendary, weight: 0),
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
