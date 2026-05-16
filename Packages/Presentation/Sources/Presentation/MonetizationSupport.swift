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

    public static let activeCreatorPassProductIDs: [String] = [
        creatorPassLifetime
    ]

    public static let allProductIDs: [String] =
        (ticketPacks.map(\.productID) + activeCreatorPassProductIDs).sorted()

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
        "外部決済リンクはありません",
        "購入前に確率を確認できます",
        "参加は無料です。コミュニティ作成のみCreator Pass機能です。"
    ]

    public static let ownershipLines = [
        "アイテムはアプリ内装飾用です",
        "現金価値はありません",
        "譲渡・売買はできません",
        "マーケットプレイスはありません",
        "重複する場合があります"
    ]
}

public enum StoreProductLoadState: Equatable, Sendable {
    case loading
    case loaded
    case partiallyLoaded
    case unavailable
    case failed(String)
}

public struct StoreProductDiagnosticsSnapshot: Equatable, Sendable {
    public struct ProductLine: Equatable, Sendable, Identifiable {
        public let productID: String
        public let displayName: String
        public let displayPrice: String?
        public let currencyCode: String?
        public let localeIdentifier: String?

        public var id: String { productID }

        public init(
            productID: String,
            displayName: String,
            displayPrice: String?,
            currencyCode: String?,
            localeIdentifier: String?
        ) {
            self.productID = productID
            self.displayName = displayName
            self.displayPrice = displayPrice
            self.currencyCode = currencyCode
            self.localeIdentifier = localeIdentifier
        }
    }

    public let availability: StoreProductLoadState
    public let requestedProductIDs: [String]
    public let loadedProductIDs: [String]
    public let missingProductIDs: [String]
    public let productCount: Int
    public let loadedProducts: [ProductLine]
    public let storefrontCountryCode: String?
    public let storefrontIdentifier: String?
    public let storefrontCurrencyCode: String?
    public let deviceLocaleIdentifier: String
    public let deviceCurrencyCode: String?
    public let appPreferredLanguages: [String]
    public let lastStoreKitError: String?
    public let lastRefreshText: String?
    public let lastSyncText: String?
    public let creatorPassStatusText: String
    public let isCreatorPassActive: Bool

    public var loadedProductCount: Int { loadedProductIDs.count }
    public var hasZeroProducts: Bool { loadedProductIDs.isEmpty }
    public var hasPartialLoad: Bool { !loadedProductIDs.isEmpty && !missingProductIDs.isEmpty }
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
            let isEnabled = (availability == .loaded || availability == .partiallyLoaded) && isLoaded
            let statusText: String
            switch availability {
            case .loading:
                statusText = "価格情報を確認中です"
            case .loaded:
                statusText = isLoaded ? "購入できます" : "価格情報を準備中です"
            case .partiallyLoaded:
                statusText = isLoaded ? "購入できます" : "価格情報を準備中です"
            case .unavailable:
                statusText = "価格情報を準備中です"
            case .failed:
                statusText = "価格情報を準備中です"
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
        let enabled = (availability == .loaded || availability == .partiallyLoaded) && creatorPassLoaded
        let statusText: String
        switch availability {
        case .loading:
            statusText = "価格情報を確認中です"
        case .loaded:
            statusText = creatorPassLoaded ? "Creator Pass を購入できます" : "価格情報を準備中です"
        case .partiallyLoaded:
            statusText = creatorPassLoaded ? "Creator Pass を購入できます" : "価格情報を準備中です"
        case .unavailable:
            statusText = "現在、価格情報を準備中です"
        case .failed:
            statusText = "現在、価格情報を準備中です"
        }

        return CreatorPassPreviewState(
            displayPrice: displayPrice,
            isPurchaseEnabled: enabled,
            statusText: statusText
        )
    }
}

public enum MonetizationDiagnosticsSupport {
    public static func makeSnapshot(
        availability: StoreProductLoadState,
        requestedProductIDs: [String],
        loadedProductIDs: [String],
        loadedProducts: [StoreProductDiagnosticsSnapshot.ProductLine],
        storefrontCountryCode: String?,
        storefrontIdentifier: String?,
        storefrontCurrencyCode: String?,
        deviceLocaleIdentifier: String,
        deviceCurrencyCode: String?,
        appPreferredLanguages: [String],
        lastStoreKitError: String?,
        lastRefreshText: String?,
        lastSyncText: String?,
        creatorPassStatusText: String,
        isCreatorPassActive: Bool
    ) -> StoreProductDiagnosticsSnapshot {
        let requested = requestedProductIDs.sorted()
        let loaded = loadedProductIDs.sorted()
        let loadedSet = Set(loaded)
        let missing = requested.filter { !loadedSet.contains($0) }

        return StoreProductDiagnosticsSnapshot(
            availability: availability,
            requestedProductIDs: requested,
            loadedProductIDs: loaded,
            missingProductIDs: missing,
            productCount: loaded.count,
            loadedProducts: loadedProducts.sorted { $0.productID < $1.productID },
            storefrontCountryCode: storefrontCountryCode,
            storefrontIdentifier: storefrontIdentifier,
            storefrontCurrencyCode: storefrontCurrencyCode,
            deviceLocaleIdentifier: deviceLocaleIdentifier,
            deviceCurrencyCode: deviceCurrencyCode,
            appPreferredLanguages: appPreferredLanguages,
            lastStoreKitError: lastStoreKitError,
            lastRefreshText: lastRefreshText,
            lastSyncText: lastSyncText,
            creatorPassStatusText: creatorPassStatusText,
            isCreatorPassActive: isCreatorPassActive
        )
    }

    public static func reportText(
        from snapshot: StoreProductDiagnosticsSnapshot
    ) -> String {
        var lines: [String] = []
        lines.append("状態: \(availabilityText(snapshot.availability))")
        lines.append("要求した商品ID: \(snapshot.requestedProductIDs.joined(separator: ", "))")
        lines.append("読み込めた商品ID: \(snapshot.loadedProductIDs.joined(separator: ", "))")
        lines.append("未取得の商品ID: \(snapshot.missingProductIDs.joined(separator: ", "))")
        lines.append("商品数: \(snapshot.productCount)")
        lines.append("Storefront国コード: \(snapshot.storefrontCountryCode ?? "取得不可")")
        lines.append("Storefront ID: \(snapshot.storefrontIdentifier ?? "取得不可")")
        lines.append("Storefront通貨: \(snapshot.storefrontCurrencyCode ?? "取得不可")")
        lines.append("端末Locale: \(snapshot.deviceLocaleIdentifier)")
        lines.append("端末通貨: \(snapshot.deviceCurrencyCode ?? "取得不可")")
        lines.append("アプリ言語: \(snapshot.appPreferredLanguages.joined(separator: ", "))")
        lines.append("最終更新: \(snapshot.lastRefreshText ?? "まだありません")")
        lines.append("最終復元: \(snapshot.lastSyncText ?? "まだありません")")
        lines.append("Creator Pass: \(snapshot.creatorPassStatusText)")
        lines.append("最後のエラー: \(snapshot.lastStoreKitError ?? "なし")")

        if snapshot.loadedProducts.isEmpty {
            lines.append("読み込めた商品詳細: なし")
        } else {
            lines.append("読み込めた商品詳細:")
            for product in snapshot.loadedProducts {
                lines.append("- \(product.productID)")
                lines.append("  表示名: \(product.displayName)")
                lines.append("  displayPrice: \(product.displayPrice ?? "取得不可")")
                lines.append("  currencyCode: \(product.currencyCode ?? "取得不可")")
                lines.append("  priceLocale: \(product.localeIdentifier ?? "取得不可")")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func availabilityText(_ availability: StoreProductLoadState) -> String {
        switch availability {
        case .loading:
            return "loading"
        case .loaded:
            return "loaded"
        case .partiallyLoaded:
            return "partiallyLoaded"
        case .unavailable:
            return "unavailable"
        case .failed(let message):
            return "failed (\(message))"
        }
    }
}
