import Foundation
import Domain

public enum GachaThemeOwnershipState: String, Equatable, Sendable {
    case equipped
    case owned
    case locked

    public var label: String {
        switch self {
        case .equipped:
            return "装備中"
        case .owned:
            return "所持"
        case .locked:
            return "未所持"
        }
    }
}

public enum GachaThemePresentation {
    public static func rarityLabel(for rarity: CardDecorationRarity) -> String {
        switch rarity {
        case .common:
            return "ノーマル"
        case .rare:
            return "レア"
        case .epic:
            return "エピック"
        case .legendary:
            return "レジェンド"
        }
    }

    public static func revealPhrase(for rarity: CardDecorationRarity) -> String {
        switch rarity {
        case .common:
            return "気軽に使える定番テーマ"
        case .rare:
            return "少し特別な雰囲気をまとえる一枚"
        case .epic:
            return "見た瞬間に空気が変わる主役級テーマ"
        case .legendary:
            return "プロフィールもシェアカードも輝く特別演出"
        }
    }

    public static func flavorText(for item: CardDecoration) -> String {
        let normalized = item.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if containsAny(normalized, ["sakura", "paper", "linen", "cotton", "plaid"]) {
            return "やわらかな余白と落ち着きで、言葉をやさしく包みます。"
        }
        if containsAny(normalized, ["ocean", "marine", "teal", "ripple", "tidal", "sonar"]) {
            return "静かな波のような透明感で、気持ちを澄ませてくれるテーマです。"
        }
        if containsAny(normalized, ["neon", "hologram", "matrix", "arcade", "volt", "glitch"]) {
            return "光のアクセントが一言を印象的に見せてくれる、都会的なデコレーションです。"
        }
        if containsAny(normalized, ["aurora", "crystal", "mint", "cloud", "nebula", "pearl", "sage"]) {
            return "淡い光の重なりで、何気ない一日にも余韻を残してくれます。"
        }
        if containsAny(normalized, ["gold", "royal", "phoenix", "prism", "auric", "crown", "halo"]) {
            return "視線を集める華やかさで、プロフィールもシェアカードもぐっと映えます。"
        }
        if containsAny(normalized, ["stardust", "starlight", "nova", "galaxy", "celestial", "zenith", "comet", "moonlit", "eclipse", "singularity"]) {
            return "夜空のきらめきをまとって、ひとことに物語の余韻を添えます。"
        }
        if containsAny(normalized, ["noir", "graphite", "ink", "inkdrop", "obsidian", "brick", "fog"]) {
            return "コントラストを効かせた落ち着いた質感で、言葉そのものを引き立てます。"
        }

        switch item.rarity {
        case .common:
            return "毎日の記録にそっと寄り添う、使いやすいベーシックテーマです。"
        case .rare:
            return "少し気分を変えたい日にちょうどいい、印象のあるテーマです。"
        case .epic:
            return "いつもの一文を、見返したくなる一枚に変えてくれます。"
        case .legendary:
            return "特別な存在感で、装備した瞬間に世界観が切り替わるテーマです。"
        }
    }

    public static func usageText(for item: CardDecoration) -> String {
        switch item.rarity {
        case .common, .rare:
            return "プロフィールカードとプレビューカードで雰囲気が変わります。"
        case .epic:
            return "プロフィールカード、結果プレビュー、共有カードで存在感を発揮します。"
        case .legendary:
            return "プロフィールカード、共有カード、結果プレビューで強い個性が出ます。"
        }
    }

    public static func sampleJournalAnswer(for item: CardDecoration) -> String {
        let normalized = item.id.lowercased()
        if containsAny(normalized, ["ocean", "marine", "teal", "ripple", "tidal", "sonar"]) {
            return "深呼吸したら、気持ちが少し静かになった。"
        }
        if containsAny(normalized, ["neon", "hologram", "matrix", "arcade", "volt", "glitch"]) {
            return "小さなひらめきが、今日はちゃんと光って見えた。"
        }
        if containsAny(normalized, ["stardust", "starlight", "nova", "galaxy", "celestial", "zenith", "comet", "moonlit", "eclipse", "singularity"]) {
            return "帰り道の空を見て、明日も少し楽しみになった。"
        }
        if containsAny(normalized, ["gold", "royal", "phoenix", "prism", "auric", "crown", "halo"]) {
            return "今日の一歩が、思っていたより誇らしかった。"
        }
        return "短いひとことでも、今日はちゃんと残しておきたい。"
    }

    public static func sampleProfileLine(for item: CardDecoration, isEquipped: Bool) -> String {
        let base = isEquipped ? "現在の装備テーマ" : "プロフィールに反映できます"
        switch item.rarity {
        case .common:
            return "\(base) ・ 日々の記録に寄り添う定番"
        case .rare:
            return "\(base) ・ 少し特別な空気感"
        case .epic:
            return "\(base) ・ 見返したくなる存在感"
        case .legendary:
            return "\(base) ・ ひと目で伝わる主役感"
        }
    }

    public static func ownershipState(isOwned: Bool, isEquipped: Bool) -> GachaThemeOwnershipState {
        if isEquipped {
            return .equipped
        }
        if isOwned {
            return .owned
        }
        return .locked
    }

    public static func shareText(
        appDisplayName: String = "ひとこと日記",
        item: CardDecoration,
        isEquipped: Bool
    ) -> String {
        let rarity = rarityLabel(for: item.rarity)
        let flavor = flavorText(for: item)
        let equipLine = isEquipped
            ? "いまはこのテーマを装備中です。"
            : "プロフィールやカードに反映できるテーマです。"

        return [
            appDisplayName,
            "\(item.name) を引きました",
            rarity,
            flavor,
            equipLine
        ]
        .joined(separator: "\n")
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }
}
