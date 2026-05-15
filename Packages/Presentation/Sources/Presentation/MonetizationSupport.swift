import Foundation

public struct GachaTicketPackDefinition: Equatable, Sendable {
    public let productID: String
    public let ticketCount: Int

    public init(productID: String, ticketCount: Int) {
        self.productID = productID
        self.ticketCount = ticketCount
    }
}

public enum CreatorPassProductKind: String, Equatable, Sendable {
    case lifetime
    case monthly
    case yearly
}

public enum MonetizationProducts {
    public static let gachaTicket10 = "jp.catloverbot.MyDailyPhrase.gacha.tickets10"
    public static let gachaTicket50 = "jp.catloverbot.MyDailyPhrase.gacha.tickets50"
    public static let gachaTicket120 = "jp.catloverbot.MyDailyPhrase.gacha.tickets120"

    public static let creatorPassLifetime = "jp.catloverbot.MyDailyPhrase.creatorpass.lifetime"
    public static let creatorPassMonthly = "jp.catloverbot.MyDailyPhrase.creatorpass.monthly"
    public static let creatorPassYearly = "jp.catloverbot.MyDailyPhrase.creatorpass.yearly"

    public static let ticketPacks: [GachaTicketPackDefinition] = [
        .init(productID: gachaTicket10, ticketCount: 10),
        .init(productID: gachaTicket50, ticketCount: 50),
        .init(productID: gachaTicket120, ticketCount: 120)
    ]

    public static let creatorPassProductIDs: [String] = [
        creatorPassLifetime,
        creatorPassMonthly,
        creatorPassYearly
    ]

    public static let allProductIDs: [String] =
        (ticketPacks.map(\.productID) + creatorPassProductIDs).sorted()

    public static let oddsDisclosureVersion = "2026.05"

    public static func ticketPack(for productID: String) -> GachaTicketPackDefinition? {
        ticketPacks.first { $0.productID == productID }
    }

    public static func isCreatorPassProduct(_ productID: String) -> Bool {
        creatorPassProductIDs.contains(productID)
    }

    public static func creatorPassKind(for productID: String) -> CreatorPassProductKind? {
        switch productID {
        case creatorPassLifetime:
            return .lifetime
        case creatorPassMonthly:
            return .monthly
        case creatorPassYearly:
            return .yearly
        default:
            return nil
        }
    }
}

public enum MonetizationDisclosure {
    public static let purchaseSafetyLines = [
        "購入はApple IDに請求されます",
        "ガチャチケットはアプリ内装飾アイテムの獲得に使えます",
        "獲得アイテムに現金価値はありません",
        "購入前に確率を確認できます",
        "参加は無料です。コミュニティ作成のみCreator Pass機能です。"
    ]

    public static let ownershipLines = [
        "アイテムはアプリ内装飾用です",
        "現金価値はありません",
        "譲渡・売買はできません",
        "重複する場合があります"
    ]
}

public enum StoreProductLoadState: Equatable, Sendable {
    case loading
    case loaded
    case unavailable
    case failed(String)
}

public struct TicketPackPurchaseCardState: Equatable, Sendable, Identifiable {
    public let productID: String
    public let title: String
    public let ticketCount: Int
    public let displayPrice: String?
    public let isEnabled: Bool
    public let statusText: String
    public let isRecommended: Bool

    public var id: String { productID }
}

public struct CreatorPassPreviewState: Equatable, Sendable {
    public let displayPrice: String?
    public let isPurchaseEnabled: Bool
    public let statusText: String
}

public enum MonetizationShopSupport {
    public static func ticketPackStates(
        availability: StoreProductLoadState,
        loadedProductIDs: Set<String>,
        displayPrices: [String: String],
        bestValueProductID: String?
    ) -> [TicketPackPurchaseCardState] {
        MonetizationProducts.ticketPacks.map { pack in
            let isLoaded = loadedProductIDs.contains(pack.productID)
            let isEnabled = availability == .loaded && isLoaded
            let statusText: String
            switch availability {
            case .loading:
                statusText = "商品情報を読み込み中です"
            case .loaded:
                statusText = isLoaded ? "購入できます" : "現在購入を準備中です"
            case .unavailable:
                statusText = "価格情報を取得できないため、現在購入はできません"
            case .failed:
                statusText = "App Storeの商品情報を読み込めませんでした"
            }

            return TicketPackPurchaseCardState(
                productID: pack.productID,
                title: "ガチャチケット\(pack.ticketCount)枚",
                ticketCount: pack.ticketCount,
                displayPrice: displayPrices[pack.productID],
                isEnabled: isEnabled,
                statusText: statusText,
                isRecommended: bestValueProductID == pack.productID
            )
        }
    }

    public static func creatorPassState(
        availability: StoreProductLoadState,
        creatorPassLoaded: Bool,
        displayPrice: String?
    ) -> CreatorPassPreviewState {
        let enabled = availability == .loaded && creatorPassLoaded
        let statusText: String
        switch availability {
        case .loading:
            statusText = "購入情報を読み込み中です"
        case .loaded:
            statusText = creatorPassLoaded ? "Creator Pass を購入できます" : "購入情報を準備中です"
        case .unavailable:
            statusText = "現在、購入情報を準備中です"
        case .failed:
            statusText = "現在、購入情報を準備中です"
        }

        return CreatorPassPreviewState(
            displayPrice: displayPrice,
            isPurchaseEnabled: enabled,
            statusText: statusText
        )
    }
}
