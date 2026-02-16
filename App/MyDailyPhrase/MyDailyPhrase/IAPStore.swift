import Foundation
import Combine
import StoreKit
import Domain

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
        case creatorPass
        case unknown
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

    // ===== Injected =====
    private let updateMyProfile: UpdateMyProfileUseCase
    private let defaults: UserDefaults

    // ===== Config =====
    private let ticketProductAmounts: [String: Int] = [
        "mydailyphrase.gacha.ticket10": 10,
        "mydailyphrase.gacha.ticket50": 50,
        "mydailyphrase.gacha.ticket120": 120,
        "mydailyphrase.gacha.ticket300": 300
    ]
    private let creatorPassProductIDs: Set<String> = [
        "mydailyphrase.creatorpass.monthly",
        "mydailyphrase.creatorpass.yearly"
    ]

    // ===== Dedup =====
    private let processedKey = "MyDailyPhrase.iap.processedTxIds.v1"
    private let processedMaxCount = 200
    private var updatesTask: Task<Void, Never>? = nil

    private var productIDs: [String] {
        Array(Set(Array(ticketProductAmounts.keys) + Array(creatorPassProductIDs))).sorted()
    }

    var ticketProducts: [Product] {
        products
            .filter { ticketProductAmounts[$0.id] != nil }
            .sorted { lhs, rhs in
                let la = ticketProductAmounts[lhs.id] ?? 0
                let ra = ticketProductAmounts[rhs.id] ?? 0
                if la != ra { return la < ra }
                return lhs.id < rhs.id
            }
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
            .filter { creatorPassProductIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.id < rhs.id
            }
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
            "今週急上昇のバズ通知を受け取れる",
            "バズお題の投稿詳細を全件表示できる",
            "毎日の無料券に +\(Self.creatorPassDailyBonusTickets) ボーナス"
        ]
    }

    var ticketValuePitchLines: [String] {
        [
            "チケットは即時付与。思い立った瞬間に回せます",
            "BEST VALUEのパックは長期運用向け",
            "Creator Pass併用で毎日無料券ボーナス"
        ]
    }

    func ticketAmount(for product: Product) -> Int {
        ticketProductAmounts[product.id] ?? 0
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
        do {
            let ps = try await Product.products(for: productIDs)
            self.products = ps.sorted { $0.id < $1.id }
            state = .ready
        } catch {
            state = .failed("Productsの取得に失敗: \(error.localizedDescription)")
        }
    }

    /// Consumable中心なので「復元」は限定的だが、環境不整合時の同期として用意
    func sync() async {
        do {
            try await AppStore.sync()
            await refreshCreatorPassEntitlement()
            lastMessage = "App Storeと同期しました"
        } catch {
            lastMessage = "同期に失敗: \(error.localizedDescription)"
        }
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

            case .userCancelled:
                lastMessage = "購入をキャンセルしました"

            case .pending:
                lastMessage = "購入が保留中です（承認後に反映されます）"

            @unknown default:
                lastMessage = "不明な購入状態です"
            }
        } catch {
            lastMessage = "購入に失敗: \(error.localizedDescription)"
        }
    }

    func kind(for product: Product) -> ProductKind {
        if let amount = ticketProductAmounts[product.id] {
            return .ticketPack(amount: amount)
        }
        if creatorPassProductIDs.contains(product.id) {
            return .creatorPass
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
        if creatorPassProductIDs.contains(tx.productID) {
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
            guard creatorPassProductIDs.contains(tx.productID) else { continue }
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
        ticketProductAmounts[productID] ?? 0
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
}
