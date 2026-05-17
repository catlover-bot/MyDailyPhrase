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

    @Test("catalog items map explicit bundled artwork names when available")
    func catalogItemsMapExplicitBundledArtworkNames() throws {
        let expectedMappings: [String: String] = [
            "sunset": "gacha_sunset_note",
            "sakura": "gacha_sakura_diary",
            "ocean": "gacha_deepsea_memo",
            "neon": "gacha_neon_city",
            "season_gold_halo": "gacha_cat_paw_badge",
            "obsidian": "gacha_pixel_frame",
            "forest": "gacha_rpg_tavern_skin",
            "starlight": "gacha_starfall_effect"
        ]

        for (decorationID, assetName) in expectedMappings {
            let item = try #require(CardDecorationCatalog.item(for: decorationID))
            #expect(item.assetName == assetName)
            #expect(item.thumbnailAssetName == nil)
        }

        let classic = try #require(CardDecorationCatalog.item(for: CardDecorationCatalog.classicId))

        #expect(classic.assetName == nil)
        #expect(classic.thumbnailAssetName == nil)
        #expect(!CardDecorationCatalog.items.contains { $0.assetName?.hasSuffix("_art") == true })
    }

    @Test("legendary asset names stay stable")
    func legendaryAssetMappingsStayStable() throws {
        let expectedMappings: [String: String] = [
            "gold": "gacha_gold",
            "royal": "gacha_royal",
            "phoenix": "gacha_phoenix",
            "eclipse": "gacha_eclipse",
            "prism": "gacha_prism",
            "celestial": "gacha_celestial",
            "auric": "gacha_auric",
            "zenith": "gacha_zenith",
            "nova": "gacha_nova",
            "galaxy": "gacha_galaxy",
            "singularity": "gacha_singularity"
        ]

        for (decorationID, assetName) in expectedMappings {
            let item = try #require(CardDecorationCatalog.item(for: decorationID))
            #expect(item.assetName == assetName)
        }
    }

    @Test("all gacha items have stable lowercase snake case asset names")
    func allGachaItemsHaveStableAssetNames() {
        let gachaItems = CardDecorationCatalog.items.filter { $0.id != CardDecorationCatalog.classicId }
        let assetNames = gachaItems.compactMap(\.assetName)

        #expect(assetNames.count == gachaItems.count)
        #expect(assetNames.allSatisfy { $0.range(of: #"^gacha_[a-z0-9_]+$"#, options: .regularExpression) != nil })
        #expect(assetNames.allSatisfy { !$0.hasSuffix("_art") })
        #expect(assetNames.allSatisfy { "\($0).png".hasSuffix(".png") })
    }

    @Test("every catalog entry has a corresponding inventory item")
    func everyCatalogEntryHasInventoryMetadata() {
        #expect(CardDecorationCatalog.items.count == CardDecorationCatalog.all.count)
        #expect(Set(CardDecorationCatalog.items.map(\.id)).count == CardDecorationCatalog.all.count)
    }

    @Test("normal gacha pool excludes classic and season limited zero weight items")
    func normalPoolExcludesClassicAndSeasonLimitedZeroWeightItems() {
        #expect(!CardDecorationCatalog.pool.contains { $0.id == CardDecorationCatalog.classicId })
        #expect(!CardDecorationCatalog.pool.contains { CardDecorationCatalog.isSeasonLimited($0.id) })
        #expect(CardDecorationCatalog.pool.allSatisfy { $0.weight > 0 })
    }
}
