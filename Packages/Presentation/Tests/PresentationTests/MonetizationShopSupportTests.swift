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
        #expect(states.allSatisfy { $0.statusText.contains("反映待ち") })
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
}
