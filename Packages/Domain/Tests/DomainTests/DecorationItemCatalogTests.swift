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
}
