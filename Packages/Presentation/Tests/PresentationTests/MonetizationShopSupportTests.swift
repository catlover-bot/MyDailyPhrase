import Foundation
import Testing
@testable import Presentation

@Suite("Monetization shop support")
struct MonetizationShopSupportTests {
    @Test("ticket packs stay visible but disabled when StoreKit is unavailable")
    func unavailableTicketPackStates() {
        let states = MonetizationShopSupport.ticketPackStates(
            availability: .failed("network"),
            loadedProductIDs: [],
            displayPrices: [:],
            bestValueProductID: nil
        )

        #expect(states.count == 3)
        #expect(states.allSatisfy { !$0.isEnabled })
        #expect(states.allSatisfy { $0.statusText.contains("準備中") })
    }

    @Test("loaded product enables only matching purchase cards")
    func loadedTicketPackStates() {
        let states = MonetizationShopSupport.ticketPackStates(
            availability: .loaded,
            loadedProductIDs: [MonetizationProducts.gachaTicket50],
            displayPrices: [MonetizationProducts.gachaTicket50: "¥800"],
            bestValueProductID: MonetizationProducts.gachaTicket50
        )

        let ten = states.first { $0.productID == MonetizationProducts.gachaTicket10 }
        let fifty = states.first { $0.productID == MonetizationProducts.gachaTicket50 }

        #expect(ten?.isEnabled == false)
        #expect(fifty?.isEnabled == true)
        #expect(fifty?.displayPrice == "¥800")
        #expect(fifty?.isRecommended == true)
    }

    @Test("partial product loading keeps loaded packs enabled and missing packs disabled")
    func partialLoadStates() {
        let states = MonetizationShopSupport.ticketPackStates(
            availability: .partiallyLoaded,
            loadedProductIDs: [MonetizationProducts.gachaTicket10, MonetizationProducts.gachaTicket120],
            displayPrices: [
                MonetizationProducts.gachaTicket10: "¥160",
                MonetizationProducts.gachaTicket120: "¥1,500"
            ],
            bestValueProductID: MonetizationProducts.gachaTicket120
        )

        let ten = states.first { $0.productID == MonetizationProducts.gachaTicket10 }
        let fifty = states.first { $0.productID == MonetizationProducts.gachaTicket50 }
        let oneTwenty = states.first { $0.productID == MonetizationProducts.gachaTicket120 }

        #expect(ten?.isEnabled == true)
        #expect(fifty?.isEnabled == false)
        #expect(fifty?.statusText.contains("準備中") == true)
        #expect(oneTwenty?.isEnabled == true)
    }

    @Test("creator pass preview remains locked when product is unavailable")
    func creatorPassUnavailableState() {
        let state = MonetizationShopSupport.creatorPassState(
            availability: .unavailable,
            creatorPassLoaded: false,
            displayPrice: nil
        )

        #expect(state.isPurchaseEnabled == false)
        #expect(state.statusText.contains("価格情報"))
    }

    @Test("diagnostics snapshot lists missing product IDs")
    func diagnosticsSnapshotTracksMissingIDs() {
        let snapshot = MonetizationDiagnosticsSupport.makeSnapshot(
            availability: .partiallyLoaded,
            requestedProductIDs: MonetizationProducts.allProductIDs,
            loadedProductIDs: [MonetizationProducts.gachaTicket10, MonetizationProducts.creatorPassLifetime],
            loadedProducts: [
                .init(
                    productID: MonetizationProducts.gachaTicket10,
                    displayName: "ガチャチケット10枚",
                    displayPrice: "$0.99",
                    currencyCode: "USD",
                    localeIdentifier: "en_US"
                )
            ],
            storefrontCountryCode: "US",
            storefrontIdentifier: "143441",
            storefrontCurrencyCode: "USD",
            deviceLocaleIdentifier: "ja_JP",
            deviceCurrencyCode: "JPY",
            appPreferredLanguages: ["ja"],
            lastStoreKitError: "none",
            lastRefreshText: "2026/05/16 12:00:00",
            lastSyncText: nil,
            creatorPassStatusText: "Creator Pass 有効",
            isCreatorPassActive: true
        )

        #expect(snapshot.productCount == 2)
        #expect(snapshot.hasPartialLoad == true)
        #expect(snapshot.missingProductIDs.contains(MonetizationProducts.gachaTicket50))
        #expect(snapshot.missingProductIDs.contains(MonetizationProducts.gachaTicket120))
        #expect(!snapshot.missingProductIDs.contains(MonetizationProducts.creatorPassLifetime))
    }

    @Test("diagnostics report keeps StoreKit display price and storefront info")
    func diagnosticsReportIncludesDisplayPrice() {
        let snapshot = MonetizationDiagnosticsSupport.makeSnapshot(
            availability: .loaded,
            requestedProductIDs: MonetizationProducts.allProductIDs,
            loadedProductIDs: [MonetizationProducts.gachaTicket50],
            loadedProducts: [
                .init(
                    productID: MonetizationProducts.gachaTicket50,
                    displayName: "ガチャチケット50枚",
                    displayPrice: "$4.99",
                    currencyCode: "USD",
                    localeIdentifier: "en_US"
                )
            ],
            storefrontCountryCode: "US",
            storefrontIdentifier: "143441",
            storefrontCurrencyCode: "USD",
            deviceLocaleIdentifier: "ja_JP",
            deviceCurrencyCode: "JPY",
            appPreferredLanguages: ["ja"],
            lastStoreKitError: nil,
            lastRefreshText: "2026/05/16 12:30:00",
            lastSyncText: "2026/05/16 12:35:00",
            creatorPassStatusText: "Creator Pass 未加入",
            isCreatorPassActive: false
        )

        let report = MonetizationDiagnosticsSupport.reportText(from: snapshot)

        #expect(report.contains("$4.99"))
        #expect(report.contains("Storefront通貨: USD"))
        #expect(report.contains("端末通貨: JPY"))
        #expect(report.contains("ガチャチケット50枚"))
    }
}
