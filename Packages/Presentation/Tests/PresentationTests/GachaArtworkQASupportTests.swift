import Foundation
import Testing
@testable import Presentation

@Suite("Gacha artwork QA support")
struct GachaArtworkQASupportTests {
    @Test("artwork diagnostics can represent all items without ownership")
    func rowsIncludeAllItemsWithoutOwnership() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        #expect(rows.count == 59)
        #expect(rows.contains { $0.id == "sunset" && !$0.isOwned && !$0.isEquipped })
        #expect(rows.contains { $0.id == "classic" && $0.assetStatus == .fallbackOnly })
    }

    @Test("mapped items become missing when asset is not found")
    func mappedItemsCanBeMarkedMissing() throws {
        let row = try #require(
            GachaArtworkQASupport.rows(
                ownedDecorationIDs: ["sunset"],
                equippedDecorationID: "sunset",
                hasBundledArtwork: { _ in false }
            ).first(where: { $0.id == "sunset" })
        )

        #expect(row.assetName == "gacha_sunset_note")
        #expect(row.assetStatus == .mappedMissing)
        #expect(row.isOwned == true)
        #expect(row.isEquipped == true)
    }

    @Test("available filter keeps only bundled artwork items")
    func availableFilterWorks() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { id in
                ["sunset", "sakura"].contains(id)
            }
        )

        let filtered = GachaArtworkQASupport.filteredRows(
            from: rows,
            primaryFilter: .available,
            rarityFilter: .all,
            typeFilter: .all
        )

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.assetStatus == .available })
    }

    @Test("available artwork rows keep readable metadata")
    func availableArtworkRowsKeepMetadata() {
        let mappedIDs: Set<String> = [
            "sunset",
            "sakura",
            "ocean",
            "neon",
            "season_gold_halo",
            "obsidian",
            "forest",
            "starlight"
        ]

        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { mappedIDs.contains($0) }
        )

        let available = rows.filter { $0.assetStatus == .available }
        #expect(available.count == 8)
        #expect(available.allSatisfy { !$0.displayName.isEmpty })
        #expect(available.allSatisfy { !$0.itemTypeLabel.isEmpty })
        #expect(available.allSatisfy { !$0.applicableSurfaceLabels.isEmpty })
    }
}
