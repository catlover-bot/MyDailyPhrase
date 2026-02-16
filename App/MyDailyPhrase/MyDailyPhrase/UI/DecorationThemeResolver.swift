import Foundation
import Domain

enum DecorationThemeResolver {
    static func resolveStyleID(from raw: String, supportedStyleIDs: Set<String>) -> String {
        let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else { return fallbackClassic(in: supportedStyleIDs) }
        if supportedStyleIDs.contains(norm) { return norm }

        let keywordStyles: [(style: String, keywords: [String])] = [
            ("gold", ["gold", "royal", "crown", "phoenix", "celestial", "eclipse", "prism", "auric", "zenith", "nova"]),
            ("neon", ["neon", "volt", "holo", "hologram", "cyber", "matrix", "arcade", "sonar"]),
            ("aurora", ["aurora", "stardust", "crystal", "marine", "moonlit", "forest", "mint", "cloud", "nebula", "teal", "pearl", "sage"]),
            ("sakura", ["sakura", "petal", "rose", "spring", "bloom"]),
            ("paper", ["paper", "linen", "retro", "plaid", "cotton", "denim", "fog"]),
            ("noir", ["noir", "shadow", "obsidian", "graphite", "ink", "inkdrop", "brick"]),
            ("glitch", ["glitch", "ripple", "ember", "pixel", "mirror", "ruby"])
        ]

        for row in keywordStyles where supportedStyleIDs.contains(row.style) {
            if row.keywords.contains(where: { norm.contains($0) }) {
                return row.style
            }
        }

        if let rarity = CardDecorationCatalog.byId(norm)?.rarity {
            return fallbackByRarity(
                raw: norm,
                rarity: rarity,
                supportedStyleIDs: supportedStyleIDs
            )
        }

        return fallbackClassic(in: supportedStyleIDs)
    }

    private static func fallbackByRarity(
        raw: String,
        rarity: CardDecorationRarity,
        supportedStyleIDs: Set<String>
    ) -> String {
        let candidates: [String]
        switch rarity {
        case .common:
            candidates = ["paper", "classic", "noir"]
        case .rare:
            candidates = ["sakura", "paper", "classic"]
        case .epic:
            candidates = ["aurora", "neon", "glitch", "classic"]
        case .legendary:
            candidates = ["gold", "aurora", "neon", "classic"]
        }

        let available = candidates.filter { supportedStyleIDs.contains($0) }
        guard !available.isEmpty else { return fallbackClassic(in: supportedStyleIDs) }
        let index = Int(stableHash64(raw) % UInt64(available.count))
        return available[index]
    }

    private static func fallbackClassic(in supportedStyleIDs: Set<String>) -> String {
        if supportedStyleIDs.contains("classic") { return "classic" }
        return supportedStyleIDs.sorted().first ?? "classic"
    }

    private static func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
