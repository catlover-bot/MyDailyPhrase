import Foundation
import Testing
import Domain
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

        #expect(rows.count == CardDecorationCatalog.all.count)
        #expect(rows.contains { $0.id == "sunset" && !$0.isOwned && !$0.isEquipped })
        #expect(rows.contains { $0.id == "classic" && $0.assetStatus == .missing })
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
        #expect(row.pngFilename == "gacha_sunset_note.png")
        #expect(row.assetStatus == .prepared)
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
        #expect(filtered.allSatisfy { $0.assetStatus == .existing })
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

        let available = rows.filter { $0.assetStatus == .existing }
        #expect(available.count == 8)
        #expect(available.allSatisfy { !$0.displayName.isEmpty })
        #expect(available.allSatisfy { !$0.itemTypeLabel.isEmpty })
        #expect(available.allSatisfy { !$0.applicableSurfaceLabels.isEmpty })
    }

    @Test("surface filter keeps only matching items")
    func surfaceFilterWorks() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        let filtered = GachaArtworkQASupport.filteredRows(
            from: rows,
            primaryFilter: .all,
            rarityFilter: .all,
            typeFilter: .all,
            surfaceFilter: .profile
        )

        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.applicableSurfaces.contains(.profileCard) || $0.applicableSurfaces.contains(.titlePlate) })
    }

    @Test("search finds by asset name without ownership")
    func searchMatchesAssetNames() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        let filtered = GachaArtworkQASupport.filteredRows(
            from: rows,
            primaryFilter: .all,
            rarityFilter: .all,
            typeFilter: .all,
            surfaceFilter: .all,
            searchText: "gacha_neon_city"
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "neon")
    }

    @Test("mapped rows expose png filename based on asset name")
    func mappedRowsExposeMatchingPNGFilename() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        let mappedRows = rows.filter { $0.assetName != nil }
        #expect(!mappedRows.isEmpty)
        #expect(mappedRows.allSatisfy { row in
            guard let assetName = row.assetName else { return false }
            return row.pngFilename == "\(assetName).png"
        })
    }

    @Test("qa rows expose usage summary and primary preview without ownership")
    func rowsExposeUsagePreviewMetadata() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        #expect(rows.allSatisfy { !$0.usageSummary.isEmpty })
        #expect(rows.allSatisfy { !$0.primaryPreviewSurfaceLabel.isEmpty })
        #expect(rows.allSatisfy { $0.applicableSurfaces.contains($0.primaryPreviewSurface) })
    }

    @Test("prepared filter keeps mapped items without bundled artwork")
    func preparedFilterWorks() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        let filtered = GachaArtworkQASupport.filteredRows(
            from: rows,
            primaryFilter: .prepared,
            rarityFilter: .all,
            typeFilter: .all
        )

        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.assetStatus == .prepared })
        #expect(filtered.allSatisfy { $0.id != CardDecorationCatalog.classicId })
    }

    @Test("search can match png filename without ownership")
    func searchMatchesPNGFilename() {
        let rows = GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set<String>(),
            equippedDecorationID: nil,
            hasBundledArtwork: { _ in false }
        )

        let filtered = GachaArtworkQASupport.filteredRows(
            from: rows,
            primaryFilter: .all,
            rarityFilter: .all,
            typeFilter: .all,
            surfaceFilter: .all,
            searchText: "gacha_sunset_note.png"
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "sunset")
    }
}
