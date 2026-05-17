import Foundation
import Domain

public enum GachaArtworkQAAssetStatus: String, CaseIterable, Equatable, Sendable {
    case existing
    case prepared
    case missing

    public var label: String {
        switch self {
        case .existing:
            return "existing"
        case .prepared:
            return "prepared"
        case .missing:
            return "missing"
        }
    }
}

public enum GachaArtworkQAPrimaryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "すべて"
    case available = "画像あり"
    case missing = "画像なし"
    case prepared = "prepared"
    case unmapped = "missing"
    case pool = "ガチャ排出対象"
    case seasonLimited = "季節限定"

    public var id: String { rawValue }
}

public enum GachaArtworkQARarityFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "レアリティ: すべて"
    case common = "ノーマル"
    case rare = "レア"
    case epic = "エピック"
    case legendary = "レジェンド"

    public var id: String { rawValue }

    public var rarity: CardDecorationRarity? {
        switch self {
        case .all:
            return nil
        case .common:
            return .common
        case .rare:
            return .rare
        case .epic:
            return .epic
        case .legendary:
            return .legendary
        }
    }
}

public enum GachaArtworkQATypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "種類: すべて"
    case fullTheme = "テーマ"
    case background = "背景"
    case cardFrame = "カード枠"
    case badge = "バッジ"
    case profileTitle = "称号"
    case shareTemplate = "共有"
    case reveal = "演出"
    case promptPack = "お題"
    case journalPaper = "紙面"
    case auraStyle = "オーラ"

    public var id: String { rawValue }

    public var itemType: DecorationItemType? {
        switch self {
        case .all:
            return nil
        case .fullTheme:
            return .fullTheme
        case .background:
            return .background
        case .cardFrame:
            return .cardFrame
        case .badge:
            return .badge
        case .profileTitle:
            return .profileTitle
        case .shareTemplate:
            return .shareTemplate
        case .reveal:
            return .gachaRevealEffect
        case .promptPack:
            return .promptPack
        case .journalPaper:
            return .journalPaper
        case .auraStyle:
            return .auraStyle
        }
    }
}

public enum GachaArtworkQASurfaceFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Surface: すべて"
    case journal = "日記カード"
    case prompt = "お題カード"
    case profile = "プロフィール"
    case share = "共有カード"
    case community = "コミュニティ"
    case result = "ガチャ結果"
    case collection = "コレクション"
    case special = "背景 / オーラ / バッジ"

    public var id: String { rawValue }

    public var matchedSurfaces: [DecorationSurface]? {
        switch self {
        case .all:
            return nil
        case .journal:
            return [.journalCard]
        case .prompt:
            return [.promptCard]
        case .profile:
            return [.profileCard, .titlePlate]
        case .share:
            return [.shareCard]
        case .community:
            return [.communityCard]
        case .result:
            return [.gachaResultCard, .gachaCapsule]
        case .collection:
            return [.collectionCard]
        case .special:
            return [.appBackground, .auraFrame, .badge, .sticker]
        }
    }
}

public struct GachaArtworkQAItemRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let rarity: CardDecorationRarity
    public let rarityLabel: String
    public let weight: Int
    public let isInNormalGachaPool: Bool
    public let isSeasonLimited: Bool
    public let itemType: DecorationItemType
    public let itemTypeLabel: String
    public let assetName: String?
    public let thumbnailAssetName: String?
    public let pngFilename: String?
    public let assetStatus: GachaArtworkQAAssetStatus
    public let isOwned: Bool
    public let isEquipped: Bool
    public let applicableSurfaces: [DecorationSurface]
    public let applicableSurfaceLabels: [String]
    public let primaryPreviewSurface: DecorationSurface
    public let primaryPreviewSurfaceLabel: String
    public let usageSummary: String
}

public enum GachaArtworkQASupport {
    public static func rows(
        ownedDecorationIDs: Set<String>,
        equippedDecorationID: String?,
        hasBundledArtwork: (String) -> Bool
    ) -> [GachaArtworkQAItemRow] {
        CardDecorationCatalog.all.map { decoration in
            let metadata = CardDecorationCatalog.item(for: decoration.id)
                ?? DecorationItem(
                    id: decoration.id,
                    displayName: decoration.name,
                    rarity: decoration.rarity,
                    flavorText: "",
                    itemType: .fullTheme,
                    applicableSurfaces: [.collectionCard],
                    palette: DecorationPalette(primaryHex: "#93A1B0", secondaryHex: "#485362", accentHex: "#F2F5F8"),
                    previewStyle: .minimal
                )

            let status: GachaArtworkQAAssetStatus
            if hasBundledArtwork(decoration.id) {
                status = .existing
            } else if metadata.assetName != nil || metadata.thumbnailAssetName != nil {
                status = .prepared
            } else {
                status = .missing
            }

            return GachaArtworkQAItemRow(
                id: decoration.id,
                displayName: decoration.name,
                rarity: decoration.rarity,
                rarityLabel: rarityLabel(for: decoration.rarity),
                weight: decoration.weight,
                isInNormalGachaPool: decoration.id != CardDecorationCatalog.classicId && decoration.weight > 0,
                isSeasonLimited: CardDecorationCatalog.isSeasonLimited(decoration.id),
                itemType: metadata.itemType,
                itemTypeLabel: itemTypeLabel(for: metadata.itemType),
                assetName: metadata.assetName,
                thumbnailAssetName: metadata.thumbnailAssetName,
                pngFilename: metadata.assetName.map { "\($0).png" },
                assetStatus: status,
                isOwned: ownedDecorationIDs.contains(decoration.id),
                isEquipped: equippedDecorationID == decoration.id,
                applicableSurfaces: metadata.applicableSurfaces,
                applicableSurfaceLabels: metadata.applicableSurfaces.map(surfaceLabel(for:)),
                primaryPreviewSurface: GachaThemePresentation.primaryPreviewSurface(for: decoration),
                primaryPreviewSurfaceLabel: GachaThemePresentation.primaryPreviewSurfaceLabel(for: decoration),
                usageSummary: GachaThemePresentation.compactUsageSummary(for: decoration)
            )
        }
    }

    public static func filteredRows(
        from rows: [GachaArtworkQAItemRow],
        primaryFilter: GachaArtworkQAPrimaryFilter,
        rarityFilter: GachaArtworkQARarityFilter,
        typeFilter: GachaArtworkQATypeFilter,
        surfaceFilter: GachaArtworkQASurfaceFilter = .all,
        searchText: String = ""
    ) -> [GachaArtworkQAItemRow] {
        let normalizedSearchText = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return rows.filter { row in
            if let rarity = rarityFilter.rarity, row.rarity != rarity {
                return false
            }
            if let itemType = typeFilter.itemType, row.itemType != itemType {
                return false
            }
            if let surfaces = surfaceFilter.matchedSurfaces,
               row.applicableSurfaces.allSatisfy({ !surfaces.contains($0) }) {
                return false
            }
            if !normalizedSearchText.isEmpty {
                let haystacks = [
                    row.id,
                    row.displayName,
                    row.assetName ?? "",
                    row.thumbnailAssetName ?? "",
                    row.pngFilename ?? "",
                    row.usageSummary,
                    row.primaryPreviewSurfaceLabel,
                    row.applicableSurfaceLabels.joined(separator: " ")
                ].map { $0.lowercased() }

                if haystacks.allSatisfy({ !$0.contains(normalizedSearchText) }) {
                    return false
                }
            }

            switch primaryFilter {
            case .all:
                return true
            case .available:
                return row.assetStatus == .existing
            case .missing:
                return row.assetStatus != .existing
            case .prepared:
                return row.assetStatus == .prepared
            case .unmapped:
                return row.assetStatus == .missing
            case .pool:
                return row.isInNormalGachaPool
            case .seasonLimited:
                return row.isSeasonLimited
            }
        }
    }

    private static func rarityLabel(for rarity: CardDecorationRarity) -> String {
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

    private static func itemTypeLabel(for itemType: DecorationItemType) -> String {
        switch itemType {
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

    private static func surfaceLabel(for surface: DecorationSurface) -> String {
        switch surface {
        case .journalCard:
            return "日記カード"
        case .promptCard:
            return "お題カード"
        case .profileCard:
            return "プロフィール"
        case .shareCard:
            return "共有カード"
        case .communityCard:
            return "コミュニティ"
        case .gachaResultCard:
            return "ガチャ結果"
        case .gachaCapsule:
            return "ガチャ演出"
        case .appBackground:
            return "背景アクセント"
        case .badge:
            return "バッジ"
        case .sticker:
            return "ステッカー"
        case .auraFrame:
            return "オーラ枠"
        case .titlePlate:
            return "称号"
        case .collectionCard:
            return "コレクション"
        }
    }
}
