import Foundation
import Combine
import Domain

@MainActor
final class GachaViewModel: ObservableObject {

    nonisolated let objectWillChange = ObservableObjectPublisher()

    struct GachaBanner: Codable, Hashable, Sendable {
        var title: String
        var subtitle: String
        var note: String
        var featuredIds: [String]
    }

    /// 参照/Binding どっちでも使えるように @Published
    @Published var currentBanner: GachaBanner = .init(
        title: "ピックアップ（重み付き）",
        subtitle: "天井 + 欠片システム",
        note: "交換所/履歴/演出を強化して「回したくなる体験」に寄せます",
        featuredIds: ["gold", "aurora", "glitch"] // 好きに調整
    )

    enum State: Equatable {
        case idle
        case spinning
        case result(GachaDrawSummary)
        case error(String)
    }

    @Published private(set) var state: State = .idle

    // 表示用
    @Published private(set) var tickets: Int = 0
    @Published private(set) var shards: Int = 0
    @Published private(set) var pity: Int = 0

    @Published private(set) var selectedDecorationId: String = CardDecorationCatalog.classicId
    @Published private(set) var ownedCounts: [String: Int] = [CardDecorationCatalog.classicId: 1]

    @Published var lastMessage: String? = nil

    // ✅ 履歴（永続化）
    @Published private(set) var history: [HistoryItem] = []
    let historyLimit: Int = 30

    // 天井
    let pityMax: Int = 80

    // Injected
    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
    private let drawDecorationGacha: DrawDecorationGachaUseCase
    private let grantDailyFreeTicket: GrantDailyFreeTicketUseCase

    private let historyDefaults: UserDefaults
    private let historyKey = "MyDailyPhrase.gacha.history.v1"

    init(
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase,
        drawDecorationGacha: DrawDecorationGachaUseCase,
        grantDailyFreeTicket: GrantDailyFreeTicketUseCase,
        historyDefaults: UserDefaults = .standard
    ) {
        self.getMyProfile = getMyProfile
        self.updateMyProfile = updateMyProfile
        self.drawDecorationGacha = drawDecorationGacha
        self.grantDailyFreeTicket = grantDailyFreeTicket
        self.historyDefaults = historyDefaults

        loadHistory()
        reload()
    }

    // MARK: - Computed for UI

    var isSpinning: Bool {
        if case .spinning = state { return true }
        return false
    }

    var currentResult: GachaDrawSummary? {
        if case .result(let s) = state { return s }
        return nil
    }

    var allDecorations: [CardDecoration] { CardDecorationCatalog.all }

    var exchangeCandidates: [CardDecoration] {
        // 未所持を優先（救済として強い）
        let notOwned = CardDecorationCatalog.all.filter { $0.id != CardDecorationCatalog.classicId && !isOwned($0.id) }
        return notOwned.sorted {
            if $0.rarity.rank != $1.rarity.rank { return $0.rarity.rank > $1.rarity.rank }
            return $0.name < $1.name
        }
    }

    var ownedDecorations: [(item: CardDecoration, count: Int)] {
        let catalog = Dictionary(uniqueKeysWithValues: CardDecorationCatalog.all.map { ($0.id, $0) })
        let list: [(CardDecoration, Int)] = ownedCounts.compactMap { (id, cnt) in
            guard cnt > 0, let item = catalog[id] else { return nil }
            return (item, cnt)
        }
        return list.sorted {
            if $0.0.rarity.rank != $1.0.rarity.rank { return $0.0.rarity.rank > $1.0.rarity.rank }
            return $0.0.name < $1.0.name
        }
    }

    func isOwned(_ id: String) -> Bool {
        (ownedCounts[id] ?? 0) > 0
    }

    func isSelected(_ id: String) -> Bool {
        selectedDecorationId == id
    }

    var pityText: String {
        "天井: \(pity)/\(pityMax)"
    }

    func canDraw(count: Int) -> Bool {
        tickets >= count && !isSpinning
    }

    // 提供割合表示（ざっくり：rarity別にweight合計を出す）
    struct WeightRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    var weightTable: [WeightRow] {
        let pool = CardDecorationCatalog.pool
        let total = max(1, pool.map(\.weight).reduce(0, +))

        func sum(_ r: CardDecorationRarity) -> Int {
            pool.filter { $0.rarity == r }.map(\.weight).reduce(0, +)
        }

        let rows: [(String, Int)] = [
            ("COMMON", sum(.common)),
            ("RARE", sum(.rare)),
            ("EPIC", sum(.epic)),
            ("LEGENDARY", sum(.legendary))
        ]

        return rows.map { (label, w) in
            let pct = Double(w) / Double(total) * 100.0
            return WeightRow(label: label, value: String(format: "%.1f%%", pct))
        }
    }

    // MARK: - Public API

    func load() { reload() }

    func drawOnce() { spin(count: 1) }

    func drawTen() { spin(count: 10) }

    func closeResult() {
        state = .idle
        lastMessage = nil
        reload()
    }

    func selectDecoration(id: String) {
        guard isOwned(id) else {
            state = .error("未所持の装飾です")
            lastMessage = "未所持の装飾です"
            return
        }
        _ = updateMyProfile(selectedDecorationId: id)
        reload()
        lastMessage = "「\(CardDecorationCatalog.byId(id)?.name ?? id)」を装備しました"
    }

    func grantDailyTicketIfNeeded() {
        let granted = grantDailyFreeTicket()
        reload()
        lastMessage = granted ? "本日の無料券を受け取りました" : "本日の無料券は受け取り済みです"
    }

    // ✅ 交換所
    func exchangeCost(for decoration: CardDecoration) -> Int {
        // 強い救済：レア度が上がるほど高いが、現実的に届く値にする
        switch decoration.rarity {
        case .common: return 30
        case .rare: return 60
        case .epic: return 120
        case .legendary: return 240
        }
    }

    func exchange(decorationId: String) {
        guard let item = CardDecorationCatalog.byId(decorationId) else {
            lastMessage = "不明なアイテムです"
            return
        }
        let cost = exchangeCost(for: item)
        guard shards >= cost else {
            lastMessage = "欠片が足りません（\(cost)必要）"
            return
        }

        // UserProfile の更新は drawUseCase とは別経路なので updateMyProfile を使う
        // ※ updateMyProfile が decorationShards / ownedDecorationCounts を扱える前提（あなたの現状VMがそれを参照しているため）
        let p = getMyProfile()

        var counts = p.ownedDecorationCounts
        counts[CardDecorationCatalog.classicId] = max(1, counts[CardDecorationCatalog.classicId] ?? 1)
        counts[item.id, default: 0] += 1

        _ = updateMyProfile(
            ownedDecorationCounts: counts,
            decorationShards: max(0, p.decorationShards - cost)
        )

        reload()
        lastMessage = "交換: 「\(item.name)」 (欠片-\(cost))"
    }

    // ✅ 履歴操作
    func clearHistory() {
        history = []
        saveHistory()
        lastMessage = "履歴をクリアしました"
    }

    // MARK: - Core

    private func reload() {
        let p = getMyProfile()
        tickets = p.gachaTickets
        shards = p.decorationShards
        pity = p.pityCount
        selectedDecorationId = p.selectedDecorationId
        ownedCounts = p.ownedDecorationCounts
        if (ownedCounts[CardDecorationCatalog.classicId] ?? 0) <= 0 {
            ownedCounts[CardDecorationCatalog.classicId] = 1
        }
    }

    private func spin(count: Int) {
        guard !isSpinning else { return }

        let p = getMyProfile()
        guard p.gachaTickets >= count else {
            state = .error("チケットが足りません（\(count)必要）")
            lastMessage = "チケットが足りません（\(count)必要）"
            return
        }

        state = .spinning

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)

            let summary = drawDecorationGacha(count: count)
            appendHistory(from: summary)

            reload()
            state = .result(summary)

            if !summary.drawn.isEmpty {
                let gotNames = summary.drawn.map { $0.name }.joined(separator: ", ")
                let shardMsg = summary.shardsGained > 0 ? " / 欠片+\(summary.shardsGained)" : ""
                lastMessage = "獲得: \(gotNames)\(shardMsg)"
            }
        }
    }

    // MARK: - History (Persist)

    struct HistoryItem: Identifiable, Codable, Equatable {
        let id: String
        let timestamp: TimeInterval
        let drawnIds: [String]
        let newIds: [String]
        let shardsGained: Int
        let pityAfter: Int

        var dateText: String {
            let d = Date(timeIntervalSince1970: timestamp)
            let f = DateFormatter()
            f.locale = .current
            f.dateFormat = "MM/dd HH:mm"
            return f.string(from: d)
        }

        var itemsText: String {
            let names = drawnIds.compactMap { CardDecorationCatalog.byId($0)?.name }
            return names.isEmpty ? "(no items)" : names.joined(separator: ", ")
        }
    }

    private func appendHistory(from summary: GachaDrawSummary) {
        let item = HistoryItem(
            id: UUID().uuidString,
            timestamp: Date().timeIntervalSince1970,
            drawnIds: summary.drawn.map(\.id),
            newIds: Array(summary.newIds),
            shardsGained: summary.shardsGained,
            pityAfter: summary.pityAfter
        )
        history.insert(item, at: 0)
        if history.count > historyLimit {
            history = Array(history.prefix(historyLimit))
        }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = historyDefaults.data(forKey: historyKey) else { return }
        if let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = items
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            historyDefaults.set(data, forKey: historyKey)
        }
    }
}

private extension CardDecorationRarity {
    var rank: Int {
        switch self {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}
