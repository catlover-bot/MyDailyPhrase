import Foundation
import Testing
@testable import Domain

@Suite("Decoration item catalog")
struct DecorationItemCatalogTests {

    @Test("share template items affect multiple surfaces")
    func shareTemplateItemMetadata() throws {
        let item = try #require(CardDecorationCatalog.item(for: "stardust"))

        #expect(item.itemType == .shareTemplate)
        #expect(item.applicableSurfaces.contains(.shareCard))
        #expect(item.applicableSurfaces.contains(.gachaResultCard))
        #expect(item.applicableSurfaces.contains(.profileCard))
        #expect(item.shareTemplateName != nil)
    }

    @Test("equipped set and owned records normalize from selected decoration")
    func equippedSetAndOwnedRecordsNormalize() {
        var profile = UserProfile(
            userId: "u-item",
            displayName: "Me",
            selectedDecorationId: "gold",
            equippedDecorationSet: EquippedDecorationSet(primaryDecorationId: "unknown"),
            ownedDecorationCounts: [
                CardDecorationCatalog.classicId: 1,
                "gold": 1
            ],
            ownedDecorationRecords: [:]
        )

        profile.normalize()

        #expect(profile.ownedDecorationRecords["gold"]?.count == 1)
        #expect(profile.equippedDecorationSet.primaryDecorationId == "gold")
        #expect(profile.equippedDecorationSet.profileTitleDecorationId == "gold")
    }

    @Test("item pool keeps enough variety across rarities")
    func itemPoolVarietyByRarity() {
        let pool = CardDecorationCatalog.pool
        #expect(pool.filter { $0.rarity == .common }.count >= 8)
        #expect(pool.filter { $0.rarity == .rare }.count >= 8)
        #expect(pool.filter { $0.rarity == .epic }.count >= 6)
        #expect(pool.filter { $0.rarity == .legendary }.count >= 3)
    }

    @Test("catalog items have user-facing names and surfaces")
    func userFacingItemMetadataExists() {
        let items = CardDecorationCatalog.items.filter { $0.id != CardDecorationCatalog.classicId }

        #expect(!items.isEmpty)
        #expect(items.allSatisfy { !$0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(items.allSatisfy { !$0.applicableSurfaces.isEmpty })
        #expect(items.contains { $0.applicableSurfaces.contains(.communityCard) })
    }

    @Test("catalog items expose future bundled artwork names")
    func catalogItemsExposeBundledArtworkNames() throws {
        let seasonItem = try #require(CardDecorationCatalog.item(for: "season_gold_halo"))
        let classic = try #require(CardDecorationCatalog.item(for: CardDecorationCatalog.classicId))

        #expect(CardDecorationCatalog.items.allSatisfy { $0.assetName?.hasPrefix("gacha_") == true })
        #expect(CardDecorationCatalog.items.allSatisfy { $0.thumbnailAssetName?.hasSuffix("_thumb") == true })
        #expect(CardDecorationCatalog.items.allSatisfy { $0.backgroundAssetName?.hasSuffix("_bg") == true })
        #expect(CardDecorationCatalog.items.allSatisfy { $0.frameAssetName?.hasSuffix("_frame") == true })

        #expect(classic.assetName == "gacha_classic_art")
        #expect(classic.thumbnailAssetName == "gacha_classic_thumb")
        #expect(classic.backgroundAssetName == "gacha_classic_bg")
        #expect(classic.frameAssetName == "gacha_classic_frame")

        #expect(seasonItem.assetName == "gacha_season_gold_halo_art")
        #expect(seasonItem.thumbnailAssetName == "gacha_season_gold_halo_thumb")
        #expect(seasonItem.backgroundAssetName == "gacha_season_gold_halo_bg")
        #expect(seasonItem.frameAssetName == "gacha_season_gold_halo_frame")
    }
}
