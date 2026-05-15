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
}
