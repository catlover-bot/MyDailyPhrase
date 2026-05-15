import Foundation
import Combine
import StoreKit
import Domain
import Presentation

@MainActor
final class IAPStore: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    enum ProductKind: Equatable {
        case ticketPack(amount: Int)
        case creatorPass(kind: CreatorPassProductKind?)
        case unknown
    }

    enum StoreEventStatus: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case pending
        case restored
        case purchased
        case cancelled
        case failed(String)
    }

    nonisolated static let creatorPassEntitlementKey = "MyDailyPhrase.creatorPass.active.v1"
    nonisolated static let creatorPassExpiryDateKey = "MyDailyPhrase.creatorPass.expiryDate.v1"
    nonisolated static let creatorPassDailyBonusTickets = 1

    // ===== Public State =====
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var products: [Product] = []
    @Published var lastMessage: String? = nil
    @Published private(set) var isCreatorPassActive: Bool = false
    @Published private(set) var creatorPassExpiresAt: Date? = nil
    @Published private(set) var lastStoreKitError: String? = nil
    @Published private(set) var eventStatus: StoreEventStatus = .idle

    // ===== Injected =====
    private let updateMyProfile: UpdateMyProfileUseCase
    private let defaults: UserDefaults

    // ===== Config =====
    // ===== Dedup =====
    private let processedKey = "MyDailyPhrase.iap.processedTxIds.v1"
    private let processedMaxCount = 200
    private var updatesTask: Task<Void, Never>? = nil

    private var productIDs: [String] {
        MonetizationProducts.allProductIDs
    }

    var ticketProducts: [Product] {
        products
            .filter { MonetizationProducts.ticketPack(for: $0.id) != nil }
            .sorted { lhs, rhs in
                let la = MonetizationProducts.ticketPack(for: lhs.id)?.ticketCount ?? 0
                let ra = MonetizationProducts.ticketPack(for: rhs.id)?.ticketCount ?? 0
                if la != ra { return la < ra }
                return lhs.id < rhs.id
            }
    }

    var isTicketShopAvailable: Bool {
        state == .ready && !ticketProducts.isEmpty
    }

    var hasLoadedAnyProducts: Bool {
        !products.isEmpty
    }

    var bestValueTicketProductID: String? {
        let withUnitPrice: [(String, NSDecimalNumber)] = ticketProducts.compactMap { product in
            guard let unit = unitPrice(for: product) else { return nil }
            return (product.id, NSDecimalNumber(decimal: unit))
        }
        guard !withUnitPrice.isEmpty else { return nil }
        return withUnitPrice.min { lhs, rhs in
            if lhs.1.compare(rhs.1) != .orderedSame {
                return lhs.1.compare(rhs.1) == .orderedAscending
            }
            return lhs.0 < rhs.0
        }?.0
    }

    var creatorPassProducts: [Product] {
        products
            .filter { MonetizationProducts.isCreatorPassProduct($0.id) }
            .sorted { lhs, rhs in
                let leftRank = creatorPassSortRank(for: lhs.id)
                let rightRank = creatorPassSortRank(for: rhs.id)
                if leftRank != rightRank { return leftRank < rightRank }
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.id < rhs.id
            }
    }

    var isCreatorPassShopAvailable: Bool {
        state == .ready && !creatorPassProducts.isEmpty
    }

    var creatorPassStatusText: String {
        guard isCreatorPassActive else {
            return "Creator Pass 未加入"
        }
        if let expires = creatorPassExpiresAt {
            return "Creator Pass 有効（期限: \(Self.creatorPassDateFormatter.string(from: expires))）"
        }
        return "Creator Pass 有効"
    }

    var creatorPassBenefitLines: [String] {
        [
            "コミュニティを作成できます",
            "カスタムお題シードと7日/4週プレビューを使えます",
            "所持テーマをコミュニティの見た目に反映できます",
            "毎日の無料券に +\(Self.creatorPassDailyBonusTickets) ボーナス"
        ]
    }

    var ticketValuePitchLines: [String] {
        [
            "チケットは検証済みの購入後に即時付与されます",
            "購入前に提供割合と重複時の欠片変換を確認できます",
            "アイテムに現金価値はなく、譲渡・売買はできません"
        ]
    }

    var paidGachaUnavailableMessage: String {
        "価格情報を確認できるまでは、安全のため購入できません。"
    }

    var creatorPassUnavailableMessage: String {
        "参加は無料です。価格情報を確認できるまでは、Creator Pass の購入はできません。"
    }

    var productLoadState: StoreProductLoadState {
        switch state {
        case .idle:
            return .unavailable
        case .loading:
            return .loading
        case .ready:
            return products.isEmpty ? .unavailable : .loaded
        case .failed(let message):
            return .failed(message)
        }
    }

    var loadedProductIDs: [String] {
        products.map(\.id).sorted()
    }

    var requestedProductIDs: [String] {
        productIDs
    }

    var productStatusTitle: String {
        switch productLoadState {
        case .loading:
            return "価格情報を確認しています"
        case .loaded:
            return "価格情報を読み込みました"
        case .unavailable:
            return "価格情報を準備中です"
        case .failed:
            return "価格情報を準備中です"
        }
    }

    var productStatusMessage: String {
        switch productLoadState {
        case .loading:
            return "安全に読み込めた商品だけ表示します。価格が確認できるまで購入ボタンは有効になりません。"
        case .loaded:
            return "StoreKit から取得できた商品のみ、価格と購入ボタンを表示しています。"
        case .unavailable:
            return "App Store に追加した商品情報の反映待ちです。しばらくしてから再読み込みするか、購入情報を復元してください。"
        case .failed:
            return "App Store に追加した商品情報の反映待ちです。しばらくしてから再読み込みするか、購入情報を復元してください。"
        }
    }

    #if DEBUG
    var debugStatusLines: [String] {
        [
            "state: \(String(describing: state))",
            "event: \(String(describing: eventStatus))",
            "requestedIDs: \(requestedProductIDs.joined(separator: ", "))",
            "loadedIDs: \(loadedProductIDs.joined(separator: ", "))",
            "productCount: \(products.count)",
            "lastError: \(lastStoreKitError ?? "-")",
            "storekitConfigDetection: unavailable"
        ]
    }
    #endif

    func ticketAmount(for product: Product) -> Int {
        MonetizationProducts.ticketPack(for: product.id)?.ticketCount ?? 0
    }

    func isBestValueTicketProduct(_ product: Product) -> Bool {
        product.id == bestValueTicketProductID
    }

    func ticketUnitPriceText(for product: Product) -> String? {
        guard let unit = unitPrice(for: product) else { return nil }
        let value = NSDecimalNumber(decimal: unit).doubleValue
        guard value.isFinite else { return nil }
        return String(format: "1枚あたり約 %.2f", value)
    }

    init(
        appGroupID: String,
        updateMyProfile: UpdateMyProfileUseCase
    ) {
        self.updateMyProfile = updateMyProfile

        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
        } else {
            self.defaults = .standard
            assertionFailure("AppGroup suiteName not found: \(appGroupID). Fallback to .standard.")
            #if DEBUG
            print("[IAPStore] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
            #endif
        }

        self.isCreatorPassActive = defaults.bool(forKey: Self.creatorPassEntitlementKey)
        if let storedDate = defaults.object(forKey: Self.creatorPassExpiryDateKey) as? Date {
            self.creatorPassExpiresAt = storedDate
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Bootstrap

    func configure() async {
        // 1) 商品取得
        await loadProducts()

        // 2) Entitlement同期
        await refreshCreatorPassEntitlement()

        // 3) 取りこぼし防止：未完了トランザクションを一度回収
        await processUnfinishedTransactionsOnce()

        // 4) 以後の更新を購読（多重起動防止）
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                await self?.listenTransactionUpdates()
            }
        }
    }

    func loadProducts() async {
        state = .loading
        eventStatus = .loading
        lastStoreKitError = nil
        do {
            let ps = try await Product.products(for: productIDs)
            self.products = ps.sorted { $0.id < $1.id }
            if ps.isEmpty {
                let message = "App Storeの商品情報を読み込めませんでした"
                state = .failed(message)
                eventStatus = .unavailable
                lastStoreKitError = message
                lastMessage = "App Store の商品情報をまだ確認できませんでした。しばらくしてから再読み込みしてください。"
            } else {
                state = .ready
                eventStatus = .loaded
                lastMessage = "商品情報を更新しました"
            }
        } catch {
            let debugMessage = error.localizedDescription
            let message = "App Storeの商品情報を読み込めませんでした"
            state = .failed(message)
            eventStatus = .failed(message)
            lastStoreKitError = debugMessage
            lastMessage = "App Store の商品情報をまだ確認できませんでした。しばらくしてから再読み込みしてください。"
        }
    }

    func reloadProducts() async {
        await loadProducts()
    }

    /// Consumable中心なので「復元」は限定的だが、環境不整合時の同期として用意
    func sync() async {
        do {
            try await AppStore.sync()
            await refreshCreatorPassEntitlement()
            lastMessage = "App Storeと同期しました"
            eventStatus = .restored
        } catch {
            let debugMessage = error.localizedDescription
            lastMessage = "購入情報の復元に失敗しました。しばらくしてからお試しください。"
            lastStoreKitError = debugMessage
            eventStatus = .failed("購入情報の復元に失敗しました")
        }
    }

    func restoreCreatorPass() async {
        await sync()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let tx = try verified(verification)
                try await applyTransaction(tx)
                await tx.finish()
                eventStatus = .purchased

            case .userCancelled:
                lastMessage = "購入をキャンセルしました"
                eventStatus = .cancelled

            case .pending:
                lastMessage = "購入が保留中です（承認後に反映されます）"
                eventStatus = .pending

            @unknown default:
                lastMessage = "不明な購入状態です"
                eventStatus = .failed("不明な購入状態です")
            }
        } catch {
            let debugMessage = error.localizedDescription
            lastMessage = "購入に失敗しました。時間をおいてもう一度お試しください。"
            lastStoreKitError = debugMessage
            eventStatus = .failed("購入に失敗しました")
        }
    }

    func kind(for product: Product) -> ProductKind {
        if let amount = MonetizationProducts.ticketPack(for: product.id)?.ticketCount {
            return .ticketPack(amount: amount)
        }
        if MonetizationProducts.isCreatorPassProduct(product.id) {
            return .creatorPass(kind: MonetizationProducts.creatorPassKind(for: product.id))
        }
        return .unknown
    }

    // MARK: - Transaction Updates

    private func listenTransactionUpdates() async {
        for await update in Transaction.updates {
            if Task.isCancelled { return }
            do {
                let tx = try verified(update)
                try await applyTransaction(tx)
                await tx.finish()
            } catch {
                #if DEBUG
                print("[IAPStore] tx update failed:", error.localizedDescription)
                #endif
            }
        }
    }

    /// 起動時に「未完了（finishされていない）Transaction」を一度だけ処理
    private func processUnfinishedTransactionsOnce() async {
        for await pending in Transaction.unfinished {
            do {
                let tx = try verified(pending)
                try await applyTransaction(tx)
                await tx.finish()
            } catch {
                #if DEBUG
                print("[IAPStore] unfinished tx failed:", error.localizedDescription)
                #endif
            }
        }
    }

    private func applyTransaction(_ tx: Transaction) async throws {
        if MonetizationProducts.isCreatorPassProduct(tx.productID) {
            await refreshCreatorPassEntitlement()
            if isCreatorPassActive {
                lastMessage = "Creator Pass を有効化しました"
            }
            return
        }

        try await grantTicketsIfNeeded(for: tx)
    }

    // MARK: - Creator Pass Entitlement

    private func refreshCreatorPassEntitlement() async {
        let now = Date()

        var active = false
        var bestExpiry: Date? = nil

        for await entitlement in Transaction.currentEntitlements {
            guard let tx = try? verified(entitlement) else { continue }
            guard MonetizationProducts.isCreatorPassProduct(tx.productID) else { continue }
            guard tx.revocationDate == nil else { continue }

            if let expiry = tx.expirationDate {
                guard expiry > now else { continue }

                if !active {
                    active = true
                    bestExpiry = expiry
                } else if let current = bestExpiry, expiry > current {
                    bestExpiry = expiry
                }
            } else {
                active = true
                bestExpiry = nil
            }
        }

        isCreatorPassActive = active
        creatorPassExpiresAt = bestExpiry
        persistCreatorPassEntitlement(active: active, expiry: bestExpiry)
    }

    private func persistCreatorPassEntitlement(active: Bool, expiry: Date?) {
        defaults.set(active, forKey: Self.creatorPassEntitlementKey)
        if let expiry {
            defaults.set(expiry, forKey: Self.creatorPassExpiryDateKey)
        } else {
            defaults.removeObject(forKey: Self.creatorPassExpiryDateKey)
        }
    }

    // MARK: - Ticket Grant

    private func ticketAmount(for productID: String) -> Int {
        MonetizationProducts.ticketPack(for: productID)?.ticketCount ?? 0
    }

    private func unitPrice(for product: Product) -> Decimal? {
        let amount = ticketAmount(for: product)
        guard amount > 0 else { return nil }
        let price = NSDecimalNumber(decimal: product.price)
        let unit = price.dividing(by: NSDecimalNumber(value: amount))
        guard unit != .notANumber else { return nil }
        return unit.decimalValue
    }

    private func grantTicketsIfNeeded(for tx: Transaction) async throws {
        // 返金/取り消しは付与しない
        if tx.revocationDate != nil {
            return
        }

        let txId = String(tx.id)

        var processed = loadProcessedTxIdsOrdered()
        if processed.contains(txId) {
            return
        }

        let add = ticketAmount(for: tx.productID)
        guard add > 0 else {
            // 未知プロダクトは付与しない（安全側）
            processed = prependAndTrim(txId, into: processed)
            saveProcessedTxIdsOrdered(processed)
            return
        }

        // ✅ 付与は「加算API」を使う（取りこぼし防止）
        _ = updateMyProfile(addGachaTickets: add)

        processed = prependAndTrim(txId, into: processed)
        saveProcessedTxIdsOrdered(processed)

        lastMessage = "ガチャ券 +\(add) を付与しました"
    }

    // MARK: - Processed Tx Store (ordered)

    /// 新→旧の順で保持（先頭が最新）
    private func loadProcessedTxIdsOrdered() -> [String] {
        (defaults.array(forKey: processedKey) as? [String]) ?? []
    }

    private func saveProcessedTxIdsOrdered(_ arr: [String]) {
        defaults.set(arr, forKey: processedKey)
    }

    private func prependAndTrim(_ txId: String, into arr: [String]) -> [String] {
        if arr.contains(txId) { return arr } // 念のため

        var new = [txId]
        for id in arr where id != txId {
            new.append(id)
            if new.count >= processedMaxCount { break }
        }
        return new
    }

    // MARK: - Verify

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }

    private static let creatorPassDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func creatorPassSortRank(for productID: String) -> Int {
        switch MonetizationProducts.creatorPassKind(for: productID) {
        case .lifetime:
            return 0
        case .monthly:
            return 1
        case .yearly:
            return 2
        case nil:
            return 99
        }
    }
}
