import Foundation

public enum DecorationSurface: String, Codable, CaseIterable, Sendable {
    case journalCard
    case promptCard
    case profileCard
    case shareCard
    case gachaResultCard
    case gachaCapsule
    case appBackground
    case badge
    case sticker
    case auraFrame
    case titlePlate
    case collectionCard
}

public enum DecorationItemType: String, Codable, CaseIterable, Sendable {
    case fullTheme
    case background
    case cardFrame
    case sticker
    case badge
    case profileTitle
    case shareTemplate
    case gachaRevealEffect
    case promptPack
    case journalPaper
    case auraStyle
}

public enum DecorationPreviewStyle: String, Codable, CaseIterable, Sendable {
    case softCard
    case vividCard
    case cosmic
    case minimal
    case celebratory
}

public enum DecorationAcquisitionSource: String, Codable, CaseIterable, Sendable {
    case defaultItem
    case freeGacha
    case challenge
    case event
    case exchange
}

public struct DecorationPalette: Codable, Equatable, Sendable {
    public let primaryHex: String
    public let secondaryHex: String
    public let accentHex: String

    public init(primaryHex: String, secondaryHex: String, accentHex: String) {
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.accentHex = accentHex
    }
}

public struct DecorationItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let rarity: CardDecorationRarity
    public let flavorText: String
    public let itemType: DecorationItemType
    public let applicableSurfaces: [DecorationSurface]
    public let palette: DecorationPalette
    public let previewStyle: DecorationPreviewStyle
    public let profileTitle: String?
    public let shareTemplateName: String?
    public let revealPhraseOverride: String?

    public init(
        id: String,
        displayName: String,
        rarity: CardDecorationRarity,
        flavorText: String,
        itemType: DecorationItemType,
        applicableSurfaces: [DecorationSurface],
        palette: DecorationPalette,
        previewStyle: DecorationPreviewStyle,
        profileTitle: String? = nil,
        shareTemplateName: String? = nil,
        revealPhraseOverride: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.rarity = rarity
        self.flavorText = flavorText
        self.itemType = itemType
        self.applicableSurfaces = applicableSurfaces
        self.palette = palette
        self.previewStyle = previewStyle
        self.profileTitle = profileTitle
        self.shareTemplateName = shareTemplateName
        self.revealPhraseOverride = revealPhraseOverride
    }
}

public struct OwnedDecorationRecord: Codable, Equatable, Sendable {
    public let acquisitionDate: Date
    public let source: DecorationAcquisitionSource
    public let count: Int

    public init(
        acquisitionDate: Date,
        source: DecorationAcquisitionSource,
        count: Int
    ) {
        self.acquisitionDate = acquisitionDate
        self.source = source
        self.count = max(0, count)
    }

    public func incremented(by delta: Int = 1) -> OwnedDecorationRecord {
        OwnedDecorationRecord(
            acquisitionDate: acquisitionDate,
            source: source,
            count: max(0, count + delta)
        )
    }
}

public struct EquippedDecorationSet: Codable, Equatable, Sendable {
    public var primaryDecorationId: String
    public var profileTitleDecorationId: String?
    public var shareTemplateDecorationId: String?
    public var badgeDecorationId: String?
    public var stickerDecorationId: String?
    public var auraDecorationId: String?

    public init(
        primaryDecorationId: String = CardDecorationCatalog.classicId,
        profileTitleDecorationId: String? = nil,
        shareTemplateDecorationId: String? = nil,
        badgeDecorationId: String? = nil,
        stickerDecorationId: String? = nil,
        auraDecorationId: String? = nil
    ) {
        self.primaryDecorationId = primaryDecorationId
        self.profileTitleDecorationId = profileTitleDecorationId
        self.shareTemplateDecorationId = shareTemplateDecorationId
        self.badgeDecorationId = badgeDecorationId
        self.stickerDecorationId = stickerDecorationId
        self.auraDecorationId = auraDecorationId
    }
}
