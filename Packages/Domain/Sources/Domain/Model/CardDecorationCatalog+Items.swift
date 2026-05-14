import Foundation

public extension CardDecorationCatalog {
    static var items: [DecorationItem] {
        all.map(makeItem(for:))
    }

    static func item(for id: String) -> DecorationItem? {
        byId(id).map(makeItem(for:))
    }

    static func makeItem(for decoration: CardDecoration) -> DecorationItem {
        let type = itemType(for: decoration)
        return DecorationItem(
            id: decoration.id,
            displayName: decoration.name,
            rarity: decoration.rarity,
            flavorText: flavorText(for: decoration, type: type),
            itemType: type,
            applicableSurfaces: applicableSurfaces(for: decoration, type: type),
            palette: palette(for: decoration),
            previewStyle: previewStyle(for: decoration, type: type),
            profileTitle: profileTitle(for: decoration, type: type),
            shareTemplateName: shareTemplateName(for: decoration, type: type),
            revealPhraseOverride: revealPhraseOverride(for: decoration, type: type)
        )
    }

    private static func itemType(for decoration: CardDecoration) -> DecorationItemType {
        let normalized = decoration.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.hasPrefix("season_") {
            return .badge
        }
        if containsAny(normalized, ["paper", "linen", "cotton", "denim", "retro", "plaid", "fog", "classic"]) {
            return .journalPaper
        }
        if containsAny(normalized, ["gold", "royal", "phoenix", "prism", "auric", "crown", "halo", "eternal"]) {
            return .profileTitle
        }
        if containsAny(normalized, ["stardust", "starlight", "nova", "galaxy", "celestial", "zenith", "comet", "moonlit", "eclipse", "singularity"]) {
            return .shareTemplate
        }
        if containsAny(normalized, ["aurora", "crystal", "nebula", "mint", "cloud", "forest", "pearl", "sage", "ocean", "marine", "teal", "tidal", "ripple"]) {
            return .auraStyle
        }
        if containsAny(normalized, ["neon", "glitch", "hologram", "matrix", "arcade", "volt", "sonar"]) {
            return .gachaRevealEffect
        }
        if containsAny(normalized, ["sakura", "ruby", "amber", "brick", "obsidian", "inkdrop", "noir", "graphite"]) {
            return .cardFrame
        }
        return .fullTheme
    }

    private static func applicableSurfaces(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> [DecorationSurface] {
        switch type {
        case .fullTheme:
            return [.journalCard, .promptCard, .profileCard, .shareCard, .gachaResultCard, .collectionCard]
        case .background:
            return [.appBackground, .profileCard, .shareCard, .collectionCard]
        case .cardFrame:
            return [.journalCard, .profileCard, .shareCard, .gachaResultCard, .collectionCard]
        case .sticker:
            return [.sticker, .profileCard, .shareCard, .collectionCard]
        case .badge:
            return [.badge, .profileCard, .shareCard, .collectionCard, .gachaResultCard]
        case .profileTitle:
            return [.profileCard, .shareCard, .titlePlate, .badge, .collectionCard, .gachaResultCard]
        case .shareTemplate:
            return [.shareCard, .profileCard, .collectionCard, .gachaResultCard]
        case .gachaRevealEffect:
            return [.gachaCapsule, .gachaResultCard, .shareCard, .collectionCard]
        case .promptPack:
            return [.promptCard, .journalCard, .collectionCard]
        case .journalPaper:
            return [.journalCard, .promptCard, .collectionCard, .gachaResultCard]
        case .auraStyle:
            return [.profileCard, .shareCard, .gachaResultCard, .collectionCard, .auraFrame, .appBackground]
        }
    }

    private static func palette(for decoration: CardDecoration) -> DecorationPalette {
        let normalized = decoration.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if containsAny(normalized, ["ocean", "marine", "teal", "sonar", "tidal", "ripple"]) {
            return DecorationPalette(primaryHex: "#0F9DDA", secondaryHex: "#0A4A7C", accentHex: "#B6F2FF")
        }
        if containsAny(normalized, ["sakura", "ruby", "amber"]) {
            return DecorationPalette(primaryHex: "#E65A96", secondaryHex: "#7A3458", accentHex: "#FFD7E8")
        }
        if containsAny(normalized, ["neon", "hologram", "matrix", "arcade", "volt", "glitch"]) {
            return DecorationPalette(primaryHex: "#3CE7FF", secondaryHex: "#4F35FF", accentHex: "#E2FBFF")
        }
        if containsAny(normalized, ["stardust", "starlight", "nova", "galaxy", "celestial", "zenith", "comet", "moonlit", "eclipse", "singularity"]) {
            return DecorationPalette(primaryHex: "#6D5BFF", secondaryHex: "#140B38", accentHex: "#F5F0FF")
        }
        if containsAny(normalized, ["gold", "royal", "phoenix", "prism", "auric", "crown", "halo"]) {
            return DecorationPalette(primaryHex: "#E4A323", secondaryHex: "#714614", accentHex: "#FFF1BF")
        }
        if containsAny(normalized, ["paper", "linen", "cotton", "classic"]) {
            return DecorationPalette(primaryHex: "#B39D7E", secondaryHex: "#615446", accentHex: "#FFF9F0")
        }

        switch decoration.rarity {
        case .common:
            return DecorationPalette(primaryHex: "#93A1B0", secondaryHex: "#485362", accentHex: "#F2F5F8")
        case .rare:
            return DecorationPalette(primaryHex: "#5D88FF", secondaryHex: "#2F4077", accentHex: "#EAF0FF")
        case .epic:
            return DecorationPalette(primaryHex: "#865DFF", secondaryHex: "#33206C", accentHex: "#F2EBFF")
        case .legendary:
            return DecorationPalette(primaryHex: "#E0A11B", secondaryHex: "#6B4311", accentHex: "#FFF4D6")
        }
    }

    private static func previewStyle(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> DecorationPreviewStyle {
        switch type {
        case .journalPaper:
            return .minimal
        case .shareTemplate:
            return .cosmic
        case .profileTitle, .badge:
            return .celebratory
        case .gachaRevealEffect:
            return .vividCard
        case .auraStyle:
            return .softCard
        default:
            switch decoration.rarity {
            case .common:
                return .minimal
            case .rare:
                return .softCard
            case .epic:
                return .vividCard
            case .legendary:
                return .celebratory
            }
        }
    }

    private static func profileTitle(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> String? {
        guard type == .profileTitle || decoration.rarity == .legendary else {
            return nil
        }

        let normalized = decoration.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if containsAny(normalized, ["gold", "crown", "royal"]) {
            return "ことばの旅人"
        }
        if containsAny(normalized, ["phoenix", "ember", "auric"]) {
            return "静かな挑戦者"
        }
        if containsAny(normalized, ["moonlit", "eclipse", "zenith", "halo", "eternal"]) {
            return "夜の記録者"
        }
        return "余韻コレクター"
    }

    private static func shareTemplateName(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> String? {
        guard type == .shareTemplate || type == .gachaRevealEffect else {
            return nil
        }

        let normalized = decoration.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if containsAny(normalized, ["stardust", "starlight", "comet"]) {
            return "星屑レター"
        }
        if containsAny(normalized, ["moonlit", "eclipse", "galaxy", "singularity"]) {
            return "ナイトグロー"
        }
        if containsAny(normalized, ["neon", "hologram", "glitch", "arcade"]) {
            return "フラッシュカード"
        }
        return "テーマプレビュー"
    }

    private static func revealPhraseOverride(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> String? {
        switch type {
        case .profileTitle:
            return "プロフィールの印象を大きく変える称号テーマ"
        case .shareTemplate:
            return "シェアカードの見え方まで変わる共有向けテーマ"
        case .gachaRevealEffect:
            return "開封演出とプレビューの空気感まで変える演出テーマ"
        case .journalPaper:
            return "ひとことを丁寧に見せてくれる紙面テーマ"
        default:
            return nil
        }
    }

    private static func flavorText(
        for decoration: CardDecoration,
        type: DecorationItemType
    ) -> String {
        let normalized = decoration.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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

        switch type {
        case .profileTitle:
            return "プロフィールの肩書きやシェアカードの印象に、ひと目で伝わる個性を加えます。"
        case .shareTemplate:
            return "外に共有したくなる見た目をつくる、共有向けのテーマです。"
        case .gachaRevealEffect:
            return "引いた瞬間から気分が上がる、演出寄りのテーマです。"
        case .journalPaper:
            return "毎日の記録を読み返しやすく整える、紙面寄りのテーマです。"
        case .auraStyle:
            return "カードの縁や背景の空気感を静かに変えてくれるテーマです。"
        default:
            switch decoration.rarity {
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
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
