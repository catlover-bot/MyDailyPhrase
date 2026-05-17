import Foundation
import Testing
import Domain
@testable import Presentation

@Suite("Gacha theme presentation")
struct GachaThemePresentationTests {

    @Test("rarity labels are mapped to Japanese labels")
    func rarityLabels() {
        #expect(GachaThemePresentation.rarityLabel(for: .common) == "ノーマル")
        #expect(GachaThemePresentation.rarityLabel(for: .rare) == "レア")
        #expect(GachaThemePresentation.rarityLabel(for: .epic) == "エピック")
        #expect(GachaThemePresentation.rarityLabel(for: .legendary) == "レジェンド")
    }

    @Test("ownership state distinguishes equipped owned and locked")
    func ownershipState() {
        #expect(GachaThemePresentation.ownershipState(isOwned: true, isEquipped: true) == .equipped)
        #expect(GachaThemePresentation.ownershipState(isOwned: true, isEquipped: false) == .owned)
        #expect(GachaThemePresentation.ownershipState(isOwned: false, isEquipped: false) == .locked)
    }

    @Test("share text uses display names and excludes internal debug identifiers")
    func shareTextExcludesInternalIdentifiers() {
        let item = CardDecoration(
            id: "season_gold_crown",
            name: "Crown Sigil",
            rarity: .legendary,
            weight: 0
        )

        let text = GachaThemePresentation.shareText(item: item, isEquipped: false)

        #expect(text.contains("ひとこと日記"))
        #expect(text.contains("Crown Sigil"))
        #expect(text.contains("レジェンド"))
        #expect(!text.contains("season_gold_crown"))
        #expect(!text.localizedCaseInsensitiveContains("debug"))
        #expect(!text.localizedCaseInsensitiveContains("audit"))
    }

    @Test("share template items add a share-style line")
    func shareTemplateItemsInfluenceSharePayload() {
        let item = CardDecoration(
            id: "stardust",
            name: "Stardust",
            rarity: .epic,
            weight: 8
        )

        let text = GachaThemePresentation.shareText(item: item, isEquipped: true)

        #expect(text.contains("共有スタイル:"))
        #expect(text.contains("Stardust"))
        #expect(!text.contains("stardust\n"))
    }

    @Test("usage preview surfaces only include applicable surfaces")
    func usagePreviewSurfacesMatchApplicability() throws {
        let item = try #require(CardDecorationCatalog.byId("starlight"))
        let metadata = GachaThemePresentation.decorationItem(for: item)
        let surfaces = GachaThemePresentation.orderedUsagePreviewSurfaces(for: item)

        #expect(!surfaces.isEmpty)
        #expect(Set(surfaces) == Set(metadata.applicableSurfaces))
    }

    @Test("each item resolves a primary preview surface from its surfaces")
    func primaryPreviewSurfaceStaysApplicable() {
        for item in CardDecorationCatalog.all {
            let metadata = GachaThemePresentation.decorationItem(for: item)
            let primary = GachaThemePresentation.primaryPreviewSurface(for: item)
            #expect(metadata.applicableSurfaces.contains(primary))
        }
    }

    @Test("item type maps to expected primary preview surface")
    func itemTypeMapsToPrimarySurface() throws {
        let journal = try #require(CardDecorationCatalog.byId("linen"))
        let share = try #require(CardDecorationCatalog.byId("stardust"))
        let reveal = try #require(CardDecorationCatalog.byId("neon"))
        let badge = try #require(CardDecorationCatalog.byId("season_gold_halo"))

        #expect(GachaThemePresentation.primaryPreviewSurface(for: journal) == .journalCard)
        #expect(GachaThemePresentation.primaryPreviewSurface(for: share) == .shareCard)
        #expect(GachaThemePresentation.primaryPreviewSurface(for: reveal) == .gachaCapsule)
        #expect(GachaThemePresentation.primaryPreviewSurface(for: badge) == .badge)
    }
}
