import Foundation
import Combine
import StoreKit
import Domain

@MainActor
final class IAPStore: ObservableObject {

    nonisolated let objectWillChange = ObservableObjectPublisher()

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    // ===== Public State =====
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var products: [Product] = []
    @Published var lastMessage: String? = nil

    // ===== Injected =====
    private let updateMyProfile: UpdateMyProfileUseCase
    private let defaults: UserDefaults

    // ===== Config =====
    private let productIDs: [String] = [
        "mydailyphrase.gacha.ticket10",
        "mydailyphrase.gacha.ticket50"
    ]

    // ===== Dedup =====
    private let processedKey = "MyDailyPhrase.iap.processedTxIds.v1"
    private let processedMaxCount = 200
    private var updatesTask: Task<Void, Never>? = nil

    init(
        appGroupID: String,
        updateMyProfile: UpdateMyProfileUseCase
    ) {
        self.updateMyProfile = updateMyProfile

        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
        } else {
            #if DEBUG
            preconditionFailure("AppGroup suiteName not found: \(appGroupID). Check entitlements for ALL targets.")
            #else
            self.defaults = .standard
            #endif
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Bootstrap

    func configure() async {
        // 1) 商品取得
        await loadProducts()

        // 2) 取りこぼし防止：未完了トランザクションを一度回収
        await processUnfinishedTransactionsOnce()

        // 3) 以後の更新を購読（多重起動防止）
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

    /// consumable中心なので「復元」は基本不要だが、環境不整合時の同期として用意
    func sync() async {
        do {
            try await AppStore.sync()
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
                try await grantTicketsIfNeeded(for: tx)
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

    // MARK: - Transaction Updates

    private func listenTransactionUpdates() async {
        for await update in Transaction.updates {
            if Task.isCancelled { return }
            do {
                let tx = try verified(update)
                try await grantTicketsIfNeeded(for: tx)
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
                try await grantTicketsIfNeeded(for: tx)
                await tx.finish()
            } catch {
                #if DEBUG
                print("[IAPStore] unfinished tx failed:", error.localizedDescription)
                #endif
            }
        }
    }

    // MARK: - Ticket Grant

    private func ticketAmount(for productID: String) -> Int {
        switch productID {
        case "mydailyphrase.gacha.ticket10":
            return 10
        case "mydailyphrase.gacha.ticket50":
            return 50
        default:
            return 0
        }
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
}
