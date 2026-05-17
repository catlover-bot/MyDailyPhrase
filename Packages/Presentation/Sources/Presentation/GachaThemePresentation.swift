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
    public static func orderedUsagePreviewSurfaces(for item: CardDecoration) -> [DecorationSurface] {
        let metadata = decorationItem(for: item)
        let primary = primaryPreviewSurface(for: item)
        let priorities = Dictionary(
            uniqueKeysWithValues: metadata.applicableSurfaces.map { surface in
                (surface, surfacePriority(surface, for: metadata.itemType, primary: primary))
            }
        )

        return metadata.applicableSurfaces
            .sorted { lhs, rhs in
                let lhsPriority = priorities[lhs] ?? Int.max
                let rhsPriority = priorities[rhs] ?? Int.max
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return surfaceLabel(for: lhs) < surfaceLabel(for: rhs)
            }
    }

    public static func primaryPreviewSurface(for item: CardDecoration) -> DecorationSurface {
        let metadata = decorationItem(for: item)
        return primaryPreviewSurface(for: metadata.itemType, availableSurfaces: metadata.applicableSurfaces)
    }

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
        let labels = orderedUsagePreviewSurfaces(for: item).map(surfaceLabel(for:))
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

    public static func compactUsageSummary(for item: CardDecoration) -> String {
        let labels = orderedUsagePreviewSurfaces(for: item).map(surfaceLabel(for:))
        guard !labels.isEmpty else {
            return "見た目のプレビューに使えます"
        }

        let headlineLabels = Array(labels.prefix(2))
        if labels.count <= 2 {
            return headlineLabels.joined(separator: "・") + " で使えます"
        }
        return headlineLabels.joined(separator: "・") + " ほかで使えます"
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
                applicableSurfaces: [.profileCard, .shareCard, .journalCard, .communityCard],
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
            return "背景テーマ"
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
        orderedUsagePreviewSurfaces(for: item).map(surfaceLabel(for:))
    }

    public static func primaryPreviewSurfaceLabel(for item: CardDecoration) -> String {
        surfaceLabel(for: primaryPreviewSurface(for: item))
    }

    public static func previewLeadText(for item: CardDecoration) -> String {
        let metadata = decorationItem(for: item)

        switch metadata.itemType {
        case .journalPaper:
            return "紙面や余白のトーンが変わり、日記とお題カードにやさしく反映されます。"
        case .cardFrame:
            return "カードの縁取りや枠まわりが変わり、本文の読みやすさはそのまま保たれます。"
        case .background:
            return "背景の空気感や配色に控えめに反映され、文字は常に読みやすいままです。"
        case .badge:
            return "小さなバッジや印として反映され、プロフィールや共有カードの目印になります。"
        case .profileTitle:
            return "名前まわりの称号やプレートに反映され、プロフィールの印象を大きく変えます。"
        case .shareTemplate:
            return "共有カードの構成や雰囲気に反映され、シェア時の見え方が変わります。"
        case .promptPack:
            return "お題カードやコミュニティカードに反映され、質問の見え方や空気感が変わります。"
        case .auraStyle:
            return "カードまわりの光や縁取りに反映され、やわらかなオーラとして使われます。"
        case .gachaRevealEffect:
            return "ガチャ結果や開封演出に強く反映され、共有カードでは控えめなアクセントになります。"
        case .sticker:
            return "カードの角や小さなワンポイントとして反映され、本文を邪魔しません。"
        case .fullTheme:
            return "複数の画面にまたがって反映され、全体の雰囲気を揃えるテーマです。"
        }
    }

    public static func sampleShareCaption(for item: CardDecoration, isEquipped: Bool) -> String {
        let template = shareTemplateName(for: item) ?? "ひとことカード"
        let status = isEquipped ? "装備中" : "共有カードに反映可能"
        return "\(template) ・ \(status)"
    }

    public static func usagePreviewTitle(for surface: DecorationSurface) -> String {
        switch surface {
        case .journalCard:
            return "日記カードでの見え方"
        case .promptCard:
            return "お題カードでの見え方"
        case .profileCard:
            return "プロフィールでの見え方"
        case .shareCard:
            return "共有カードでの見え方"
        case .communityCard:
            return "コミュニティカードでの見え方"
        case .gachaResultCard:
            return "ガチャ結果での見え方"
        case .gachaCapsule:
            return "ガチャ演出での見え方"
        case .appBackground:
            return "背景アクセントでの見え方"
        case .badge:
            return "バッジでの見え方"
        case .sticker:
            return "ステッカーでの見え方"
        case .auraFrame:
            return "オーラ枠での見え方"
        case .titlePlate:
            return "称号プレートでの見え方"
        case .collectionCard:
            return "コレクションでの見え方"
        }
    }

    public static func usagePreviewDescription(
        for surface: DecorationSurface,
        item: CardDecoration,
        isEquipped: Bool
    ) -> String {
        let metadata = decorationItem(for: item)
        let equippedText = isEquipped ? "現在の装備に反映されます。" : "プレビューとして確認できます。"

        switch surface {
        case .journalCard:
            return metadata.itemType == .journalPaper
                ? "日記カードの紙面や余白に反映されます。\(equippedText)"
                : "日記カードの見た目に控えめに反映されます。\(equippedText)"
        case .promptCard:
            return metadata.itemType == .promptPack
                ? "お題カードや部屋のお題表示に反映されます。\(equippedText)"
                : "お題カードの見た目に反映されます。\(equippedText)"
        case .profileCard:
            return "プロフィールカードの背景・称号・バッジなどに反映されます。\(equippedText)"
        case .shareCard:
            return "共有カードのレイアウトや装飾に反映されます。\(equippedText)"
        case .communityCard:
            return "コミュニティカードや部屋の見た目に反映されます。\(equippedText)"
        case .gachaResultCard:
            return "獲得結果の見え方や演出プレビューに反映されます。\(equippedText)"
        case .gachaCapsule:
            return "開封アニメーションや演出の雰囲気に反映されます。\(equippedText)"
        case .appBackground:
            return "アプリ内の背景アクセントとして控えめに反映されます。\(equippedText)"
        case .badge:
            return "小さなバッジや印として反映されます。\(equippedText)"
        case .sticker:
            return "カードの隅に置かれる小さな装飾として反映されます。\(equippedText)"
        case .auraFrame:
            return "カードまわりの光や縁取りとして反映されます。\(equippedText)"
        case .titlePlate:
            return "名前や称号のまわりのプレートとして反映されます。\(equippedText)"
        case .collectionCard:
            return "コレクション一覧でも見分けやすく表示されます。\(equippedText)"
        }
    }

    public static func surfaceLabel(for surface: DecorationSurface) -> String {
        switch surface {
        case .journalCard:
            return "日記カード"
        case .promptCard:
            return "お題カード"
        case .profileCard:
            return "プロフィールカード"
        case .shareCard:
            return "共有カード"
        case .communityCard:
            return "コミュニティカード"
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

    public static func primaryEquipLabel(for item: CardDecoration, isEquipped: Bool) -> String {
        guard !isEquipped else { return "現在装備中" }

        switch decorationItem(for: item).itemType {
        case .cardFrame:
            return "カード枠に使う"
        case .profileTitle, .badge:
            return "プロフィールに使う"
        case .shareTemplate:
            return "共有カードに使う"
        case .journalPaper:
            return "日記カードに使う"
        case .promptPack:
            return "コミュニティに使う"
        case .gachaRevealEffect:
            return "ガチャ演出に使う"
        case .auraStyle:
            return "オーラに使う"
        default:
            return "まとめて装備"
        }
    }

    private static func primaryPreviewSurface(
        for itemType: DecorationItemType,
        availableSurfaces: [DecorationSurface]
    ) -> DecorationSurface {
        let preferred: [DecorationSurface]
        switch itemType {
        case .fullTheme:
            preferred = [.journalCard, .profileCard, .shareCard, .communityCard]
        case .background:
            preferred = [.profileCard, .communityCard, .shareCard, .appBackground]
        case .cardFrame:
            preferred = [.journalCard, .profileCard, .shareCard, .gachaResultCard]
        case .sticker:
            preferred = [.sticker, .shareCard, .communityCard, .collectionCard]
        case .badge:
            preferred = [.badge, .profileCard, .shareCard, .gachaResultCard]
        case .profileTitle:
            preferred = [.titlePlate, .profileCard, .shareCard]
        case .shareTemplate:
            preferred = [.shareCard, .profileCard, .communityCard]
        case .gachaRevealEffect:
            preferred = [.gachaCapsule, .gachaResultCard, .shareCard]
        case .promptPack:
            preferred = [.promptCard, .communityCard, .journalCard]
        case .journalPaper:
            preferred = [.journalCard, .promptCard, .collectionCard]
        case .auraStyle:
            preferred = [.auraFrame, .profileCard, .communityCard, .appBackground]
        }

        for surface in preferred where availableSurfaces.contains(surface) {
            return surface
        }
        return availableSurfaces.first ?? .collectionCard
    }

    private static func surfacePriority(
        _ surface: DecorationSurface,
        for itemType: DecorationItemType,
        primary: DecorationSurface
    ) -> Int {
        if surface == primary {
            return 0
        }

        switch itemType {
        case .fullTheme:
            switch surface {
            case .profileCard: return 1
            case .shareCard: return 2
            case .communityCard: return 3
            case .promptCard: return 4
            case .gachaResultCard: return 5
            case .collectionCard: return 6
            default: return 50
            }
        case .background:
            switch surface {
            case .communityCard: return 1
            case .shareCard: return 2
            case .appBackground: return 3
            case .collectionCard: return 4
            default: return 50
            }
        case .cardFrame:
            switch surface {
            case .profileCard: return 1
            case .shareCard: return 2
            case .communityCard: return 3
            case .gachaResultCard: return 4
            case .collectionCard: return 5
            default: return 50
            }
        case .sticker:
            switch surface {
            case .shareCard: return 1
            case .communityCard: return 2
            case .collectionCard: return 3
            default: return 50
            }
        case .badge:
            switch surface {
            case .profileCard: return 1
            case .shareCard: return 2
            case .communityCard: return 3
            case .gachaResultCard: return 4
            case .collectionCard: return 5
            default: return 50
            }
        case .profileTitle:
            switch surface {
            case .profileCard: return 1
            case .shareCard: return 2
            case .badge: return 3
            case .gachaResultCard: return 4
            case .collectionCard: return 5
            default: return 50
            }
        case .shareTemplate:
            switch surface {
            case .profileCard: return 1
            case .communityCard: return 2
            case .gachaResultCard: return 3
            case .collectionCard: return 4
            default: return 50
            }
        case .gachaRevealEffect:
            switch surface {
            case .gachaResultCard: return 1
            case .shareCard: return 2
            case .collectionCard: return 3
            default: return 50
            }
        case .promptPack:
            switch surface {
            case .communityCard: return 1
            case .journalCard: return 2
            case .shareCard: return 3
            case .gachaResultCard: return 4
            case .collectionCard: return 5
            default: return 50
            }
        case .journalPaper:
            switch surface {
            case .promptCard: return 1
            case .collectionCard: return 2
            case .gachaResultCard: return 3
            default: return 50
            }
        case .auraStyle:
            switch surface {
            case .profileCard: return 1
            case .communityCard: return 2
            case .shareCard: return 3
            case .gachaResultCard: return 4
            case .appBackground: return 5
            case .collectionCard: return 6
            default: return 50
            }
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
