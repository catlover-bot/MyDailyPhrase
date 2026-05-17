import Foundation
import Domain

private struct Summary: Codable {
    let totalItemCount: Int
    let normalGachaPoolCount: Int
    let seasonLimitedCount: Int
    let artworkExistingCount: Int
    let artworkPreparedCount: Int
    let artworkMissingCount: Int
    let countByRarity: [String: Int]
    let countByItemType: [String: Int]
}

private struct ManifestEntry: Codable {
    let itemID: String
    let displayName: String
    let rarity: String
    let weight: Int
    let normalGachaPool: Bool
    let seasonLimited: Bool
    let itemType: String
    let applicableSurfaces: [String]
    let currentAssetName: String?
    let plannedAssetName: String?
    let pngFilename: String?
    let importDirectory: String
    let assetCatalogImagesetPath: String?
    let artworkStatus: String
    let recommendedConceptShortDescription: String
    let flavorText: String
    let profileTitle: String?
    let shareTemplateName: String?
    let revealPhraseOverride: String?
}

private struct ManifestDocument: Codable {
    let generatedAt: String
    let source: String
    let summary: Summary
    let items: [ManifestEntry]
}

private enum ArtworkStatus: String {
    case existing
    case prepared
    case missing
}

private enum Priority: String, CaseIterable {
    case p1 = "Priority 1"
    case p2 = "Priority 2"
    case p3 = "Priority 3"
}

@main
struct DomainToolsMain {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let command = arguments.first ?? "generate-gacha-artwork"
        let repoRoot = arguments.dropFirst().first
            .map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        switch command {
        case "generate-gacha-artwork":
            try generateGachaArtworkFiles(repoRoot: repoRoot)
        default:
            fputs("Unknown command: \(command)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func generateGachaArtworkFiles(repoRoot: URL) throws {
        let assetCatalogRoot = repoRoot
            .appendingPathComponent("App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems", isDirectory: true)
        let buildVersion = currentBuildVersion(repoRoot: repoRoot) ?? "unknown"
        let items = CardDecorationCatalog.items
        let entries = items.map { entry(for: $0, assetCatalogRoot: assetCatalogRoot) }
        let summary = makeSummary(from: entries)

        let document = ManifestDocument(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: "CardDecorationCatalog.all",
            summary: summary,
            items: entries
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(document)

        try ensureDirectory(repoRoot.appendingPathComponent("artwork-imports/gacha-all", isDirectory: true))
        try ensureDirectory(repoRoot.appendingPathComponent("docs", isDirectory: true))

        try manifestData.write(to: repoRoot.appendingPathComponent("artwork-imports/gacha-all/manifest.json"))
        try renderAssetManifestMarkdown(document: document, buildVersion: buildVersion)
            .write(to: repoRoot.appendingPathComponent("docs/gacha-artwork-asset-manifest.md"), atomically: true, encoding: .utf8)
        try renderInventoryMarkdown(document: document, buildVersion: buildVersion)
            .write(to: repoRoot.appendingPathComponent("docs/gacha-item-inventory.md"), atomically: true, encoding: .utf8)
        try renderBacklogMarkdown(document: document, buildVersion: buildVersion)
            .write(to: repoRoot.appendingPathComponent("docs/gacha-artwork-backlog.md"), atomically: true, encoding: .utf8)
    }

    private static func entry(for item: DecorationItem, assetCatalogRoot: URL) -> ManifestEntry {
        let plannedAssetName = item.assetName
        let pngFilename = plannedAssetName.map { "\($0).png" }
        let imagesetPath = plannedAssetName.map {
            "App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems/\($0).imageset"
        }
        let status = artworkStatus(
            plannedAssetName: plannedAssetName,
            assetCatalogRoot: assetCatalogRoot
        )

        return ManifestEntry(
            itemID: item.id,
            displayName: item.displayName,
            rarity: rarityLabel(item.rarity),
            weight: CardDecorationCatalog.byId(item.id)?.weight ?? 0,
            normalGachaPool: CardDecorationCatalog.pool.contains { $0.id == item.id },
            seasonLimited: CardDecorationCatalog.isSeasonLimited(item.id),
            itemType: itemTypeLabel(item.itemType),
            applicableSurfaces: item.applicableSurfaces.map(surfaceLabel),
            currentAssetName: item.assetName,
            plannedAssetName: plannedAssetName,
            pngFilename: pngFilename,
            importDirectory: importDirectory(for: item),
            assetCatalogImagesetPath: imagesetPath,
            artworkStatus: status.rawValue,
            recommendedConceptShortDescription: concept(for: item),
            flavorText: item.flavorText,
            profileTitle: item.profileTitle,
            shareTemplateName: item.shareTemplateName,
            revealPhraseOverride: item.revealPhraseOverride
        )
    }

    private static func artworkStatus(
        plannedAssetName: String?,
        assetCatalogRoot: URL
    ) -> ArtworkStatus {
        guard let plannedAssetName else {
            return .missing
        }

        let pngPath = assetCatalogRoot
            .appendingPathComponent("\(plannedAssetName).imageset", isDirectory: true)
            .appendingPathComponent("\(plannedAssetName).png")

        return FileManager.default.fileExists(atPath: pngPath.path) ? .existing : .prepared
    }

    private static func makeSummary(from entries: [ManifestEntry]) -> Summary {
        Summary(
            totalItemCount: entries.count,
            normalGachaPoolCount: entries.filter(\.normalGachaPool).count,
            seasonLimitedCount: entries.filter(\.seasonLimited).count,
            artworkExistingCount: entries.filter { $0.artworkStatus == ArtworkStatus.existing.rawValue }.count,
            artworkPreparedCount: entries.filter { $0.artworkStatus == ArtworkStatus.prepared.rawValue }.count,
            artworkMissingCount: entries.filter { $0.artworkStatus == ArtworkStatus.missing.rawValue }.count,
            countByRarity: Dictionary(grouping: entries, by: \.rarity).mapValues(\.count),
            countByItemType: Dictionary(grouping: entries, by: \.itemType).mapValues(\.count)
        )
    }

    private static func renderAssetManifestMarkdown(document: ManifestDocument, buildVersion: String) -> String {
        let lines = [
            "# Gacha Artwork Asset Manifest",
            "",
            "Build \(buildVersion) 時点のアート import 用 manifest です。",
            "",
            "この manifest は `CardDecorationCatalog.all` を source of truth として生成しています。",
            "",
            "## Summary",
            "",
            "- total items: \(document.summary.totalItemCount)",
            "- normal gacha pool items: \(document.summary.normalGachaPoolCount)",
            "- season-limited items: \(document.summary.seasonLimitedCount)",
            "- artwork existing: \(document.summary.artworkExistingCount)",
            "- artwork prepared: \(document.summary.artworkPreparedCount)",
            "- artwork missing: \(document.summary.artworkMissingCount)",
            "",
            "## Import Rules",
            "",
            "- PNG は `artwork-imports/` 配下に置き、`Scripts/import_gacha_artwork_assets.sh` で取り込みます。",
            "- 画像がまだ無い item は `prepared` または `missing` のままで問題ありません。",
            "- `.imageset` は PNG が見つかったときだけ生成されます。",
            "",
            "## Item Table",
            "",
            "| item id | display name | rarity | weight | normal pool | season-limited | item type | applicable surfaces | current assetName | planned assetName | png filename | import directory | imageset path | artwork status | concept |",
            "| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
        ]

        let rows = document.items.map { item in
            "| \(item.itemID) | \(item.displayName) | \(item.rarity) | \(item.weight) | \(yesNo(item.normalGachaPool)) | \(yesNo(item.seasonLimited)) | \(item.itemType) | \(item.applicableSurfaces.joined(separator: "<br>")) | \(dash(item.currentAssetName)) | \(dash(item.plannedAssetName)) | \(dash(item.pngFilename)) | `\(item.importDirectory)` | \(dash(item.assetCatalogImagesetPath)) | \(item.artworkStatus) | \(item.recommendedConceptShortDescription) |"
        }

        return (lines + rows + [""]).joined(separator: "\n")
    }

    private static func renderInventoryMarkdown(document: ManifestDocument, buildVersion: String) -> String {
        let rarityLines = document.summary.countByRarity
            .sorted { $0.key < $1.key }
            .map { "- \($0.key): \($0.value)" }
        let typeLines = document.summary.countByItemType
            .sorted { $0.key < $1.key }
            .map { "- \($0.key): \($0.value)" }

        let lines = [
            "# Gacha Item Inventory",
            "",
            "Build \(buildVersion) 時点の `CardDecorationCatalog.all` 全件一覧です。",
            "",
            "## Summary",
            "",
            "- total items: \(document.summary.totalItemCount)",
            "- normal gacha pool count: \(document.summary.normalGachaPoolCount)",
            "- season-limited count: \(document.summary.seasonLimitedCount)",
            "- items with artwork: \(document.summary.artworkExistingCount)",
            "- items prepared for artwork: \(document.summary.artworkPreparedCount)",
            "- items without planned artwork: \(document.summary.artworkMissingCount)",
            "",
            "### Count By Rarity",
            ""
        ] + rarityLines + [
            "",
            "### Count By Item Type",
            ""
        ] + typeLines + [
            "",
            "## Artwork UI Rules",
            "",
            "- busy artwork の上に primary text を置かない",
            "- hero artwork と metadata は別カードに分ける",
            "- detailed artwork は icon / accent / watermark として控えめに使う",
            "- 日記 / プロフィール / 共有カードの本文は常に読みやすさ優先で表示する",
            "",
            "## Item Table",
            "",
            "| id | display name | rarity | weight | normal gacha pool | season-limited | item type | applicable surfaces | flavor text | profileTitle | shareTemplateName | revealPhraseOverride | assetName | thumbnailAssetName | artwork status | recommended artwork concept |",
            "| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
        ]

        let rows = document.items.map { item in
            "| \(item.itemID) | \(item.displayName) | \(item.rarity) | \(item.weight) | \(yesNo(item.normalGachaPool)) | \(yesNo(item.seasonLimited)) | \(item.itemType) | \(item.applicableSurfaces.joined(separator: "<br>")) | \(item.flavorText) | \(dash(item.profileTitle)) | \(dash(item.shareTemplateName)) | \(dash(item.revealPhraseOverride)) | \(dash(item.currentAssetName)) | - | \(item.artworkStatus) | \(item.recommendedConceptShortDescription) |"
        }

        return (lines + rows + [""]).joined(separator: "\n")
    }

    private static func renderBacklogMarkdown(document: ManifestDocument, buildVersion: String) -> String {
        let pendingItems = document.items.filter { $0.artworkStatus != ArtworkStatus.existing.rawValue }
        let grouped = Dictionary(grouping: pendingItems, by: priority(for:))

        var lines: [String] = [
            "# Gacha Artwork Backlog",
            "",
            "Build \(buildVersion) 時点で既存画像を除く、今後追加したいガチャアート候補です。",
            "",
            "## Full Artwork Import Workflow",
            "",
            "1. `artwork-imports/` の該当フォルダに PNG を置く",
            "2. `bash Scripts/import_gacha_artwork_assets.sh` を実行する",
            "3. Release build と package test を流す",
            "4. hidden `ガチャアート確認` で `prepared` が `existing` に変わることを確認する",
            "",
            "## Usage Preview Rules",
            "",
            "- busy artwork を本文の背後に置かない",
            "- detailed artwork は badge / corner / accent で扱う",
            "- 新しい item は assetName だけでなく usage preview plan も一緒に決める",
            ""
        ]

        for priority in Priority.allCases {
            let items = grouped[priority, default: []]
            guard !items.isEmpty else { continue }
            lines.append("## \(priority.rawValue)")
            lines.append("")
            lines.append("| item id | display name | rarity | item type | recommended assetName | suggested filename | visual concept | suggested prompt for image generation | suggested use surfaces | transparent background useful | PNG or vector PDF |")
            lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")

            lines += items.map { item in
                let transparent = transparentBackgroundUseful(for: item) ? "yes" : "no"
                let format = preferredFormat(for: item)
                let prompt = imagePrompt(for: item)
                return "| \(item.itemID) | \(item.displayName) | \(item.rarity) | \(item.itemType) | \(dash(item.plannedAssetName)) | \(dash(item.pngFilename)) | \(item.recommendedConceptShortDescription) | \(prompt) | \(item.applicableSurfaces.joined(separator: "<br>")) | \(transparent) | \(format) |"
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func importDirectory(for item: DecorationItem) -> String {
        if CardDecorationCatalog.isSeasonLimited(item.id) {
            return "artwork-imports/gacha-seasonal"
        }

        switch item.rarity {
        case .legendary:
            return "artwork-imports/gacha-legendary"
        case .epic:
            return "artwork-imports/gacha-epic"
        case .rare:
            return "artwork-imports/gacha-rare"
        case .common:
            return "artwork-imports/gacha-common"
        }
    }

    private static func priority(for item: ManifestEntry) -> Priority {
        if item.seasonLimited {
            return .p3
        }
        if item.rarity == "レジェンド" {
            return .p1
        }
        if ["共有テンプレート", "開封演出", "お題パック"].contains(item.itemType) || item.rarity == "エピック" {
            return .p2
        }
        return .p3
    }

    private static func concept(for item: DecorationItem) -> String {
        switch item.itemType {
        case .fullTheme:
            return "カード全体の雰囲気を整えるテーマアート"
        case .background:
            return "背景の空気感に使いやすい情景・色面アート"
        case .cardFrame:
            return "中央の文字を邪魔しない枠・縁取りアート"
        case .sticker:
            return "小さく置いて映えるステッカー系アート"
        case .badge:
            return "小さく表示しても認識しやすい紋章・バッジ系アート"
        case .profileTitle:
            return "プロフィール称号やプレートに映える高級感ある意匠"
        case .shareTemplate:
            return "共有カード全体の世界観を決めるメインビジュアル"
        case .gachaRevealEffect:
            return "ガチャ開封時の発光・粒子・演出モチーフ"
        case .promptPack:
            return "お題カードやコミュニティカード向けのテーマアート"
        case .journalPaper:
            return "紙の質感や余白が主役の読みやすい紙面アート"
        case .auraStyle:
            return "カード周囲や背景アクセントで効く柔らかな光彩"
        }
    }

    private static func imagePrompt(for item: ManifestEntry) -> String {
        "Japanese mobile gacha reward artwork for \(item.displayName), calm decorative style, no text, centered composition, \(item.recommendedConceptShortDescription)"
    }

    private static func transparentBackgroundUseful(for item: ManifestEntry) -> Bool {
        switch item.itemType {
        case "カード枠", "バッジ", "プロフィール称号", "開封演出", "オーラ":
            return true
        default:
            return false
        }
    }

    private static func preferredFormat(for item: ManifestEntry) -> String {
        switch item.itemType {
        case "バッジ":
            return "vector PDF"
        default:
            return "PNG"
        }
    }

    private static func rarityLabel(_ rarity: CardDecorationRarity) -> String {
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

    private static func itemTypeLabel(_ itemType: DecorationItemType) -> String {
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

    private static func surfaceLabel(_ surface: DecorationSurface) -> String {
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

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func dash(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "-"
        }
        return trimmed
    }

    private static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func currentBuildVersion(repoRoot: URL) -> String? {
        let projectFile = repoRoot.appendingPathComponent("App/MyDailyPhrase/MyDailyPhrase.xcodeproj/project.pbxproj")
        guard let contents = try? String(contentsOf: projectFile) else {
            return nil
        }

        let lines = contents
            .components(separatedBy: .newlines)
            .filter { $0.contains("CURRENT_PROJECT_VERSION") }

        guard let first = lines.first,
              let version = first.components(separatedBy: "=").last?
                .replacingOccurrences(of: ";", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty else {
            return nil
        }

        return version
    }
}
