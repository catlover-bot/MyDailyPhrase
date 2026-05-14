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
}
