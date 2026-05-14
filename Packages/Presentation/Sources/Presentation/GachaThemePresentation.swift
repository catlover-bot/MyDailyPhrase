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
        let metadata = CardDecorationCatalog.item(for: item.id)
        if let flavorText = metadata?.flavorText, !flavorText.isEmpty {
            return flavorText
        }

        return fallbackFlavorText(for: item)
    }

    public static func usageText(for item: CardDecoration) -> String {
        let labels = applicableSurfaceLabels(for: item)
        if labels.isEmpty {
            switch item.rarity {
            case .common, .rare:
                return "プロフィールカードとプレビューカードで雰囲気が変わります。"
            case .epic:
                return "プロフィールカード、結果プレビュー、共有カードで存在感を発揮します。"
            case .legendary:
                return "プロフィールカード、共有カード、結果プレビューで強い個性が出ます。"
            }
        }

        return labels.joined(separator: "・") + " に反映されます。"
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
        if let title = profileTitle(for: item) {
            return "\(base) ・ \(title)"
        }
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
        let titleLine = profileTitle(for: item).map { "プロフィール称号: \($0)" }
        let templateLine = shareTemplateName(for: item).map { "共有スタイル: \($0)" }

        return (
            [
            appDisplayName,
            "\(item.name) を引きました",
            rarity,
            flavor,
            equipLine
            ] + [titleLine, templateLine].compactMap { $0 }
        )
        .joined(separator: "\n")
    }

    public static func decorationItem(for item: CardDecoration) -> DecorationItem {
        CardDecorationCatalog.item(for: item.id)
            ?? DecorationItem(
                id: item.id,
                displayName: item.name,
                rarity: item.rarity,
                flavorText: fallbackFlavorText(for: item),
                itemType: .fullTheme,
                applicableSurfaces: [.profileCard, .shareCard, .journalCard],
                palette: DecorationPalette(primaryHex: "#93A1B0", secondaryHex: "#485362", accentHex: "#F2F5F8"),
                previewStyle: .softCard
            )
    }

    public static func revealPhrase(for item: CardDecoration) -> String {
        decorationItem(for: item).revealPhraseOverride ?? revealPhrase(for: item.rarity)
    }

    public static func profileTitle(for item: CardDecoration) -> String? {
        decorationItem(for: item).profileTitle
    }

    public static func shareTemplateName(for item: CardDecoration) -> String? {
        decorationItem(for: item).shareTemplateName
    }

    public static func itemTypeLabel(for item: CardDecoration) -> String {
        itemTypeLabel(for: decorationItem(for: item))
    }

    public static func itemTypeLabel(for item: DecorationItem) -> String {
        switch item.itemType {
        case .fullTheme:
            return "テーマ"
        case .background:
            return "背景"
        case .cardFrame:
            return "カード枠"
        case .sticker:
            return "ステッカー"
        case .badge:
            return "バッジ"
        case .profileTitle:
            return "プロフィール称号"
        case .shareTemplate:
            return "共有テンプレート"
        case .gachaRevealEffect:
            return "開封演出"
        case .promptPack:
            return "お題パック"
        case .journalPaper:
            return "紙面テーマ"
        case .auraStyle:
            return "オーラ"
        }
    }

    public static func applicableSurfaceLabels(for item: CardDecoration) -> [String] {
        decorationItem(for: item).applicableSurfaces.map(surfaceLabel(for:))
    }

    public static func sampleShareCaption(for item: CardDecoration, isEquipped: Bool) -> String {
        let template = shareTemplateName(for: item) ?? "ひとことカード"
        let status = isEquipped ? "装備中" : "共有カードに反映可能"
        return "\(template) ・ \(status)"
    }

    public static func surfaceLabel(for surface: DecorationSurface) -> String {
        switch surface {
        case .journalCard:
            return "ひとことカード"
        case .promptCard:
            return "お題カード"
        case .profileCard:
            return "プロフィール"
        case .shareCard:
            return "共有カード"
        case .gachaResultCard:
            return "ガチャ結果"
        case .gachaCapsule:
            return "開封演出"
        case .appBackground:
            return "背景アクセント"
        case .badge:
            return "バッジ"
        case .sticker:
            return "ステッカー"
        case .auraFrame:
            return "オーラ枠"
        case .titlePlate:
            return "称号プレート"
        case .collectionCard:
            return "コレクション"
        }
    }

    private static func fallbackFlavorText(for item: CardDecoration) -> String {
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

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }
}
