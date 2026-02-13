import Foundation
import Combine
import Domain

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var userId: String = ""
    @Published var displayName: String = ""

    // ===== Decoration / Gacha =====
    @Published private(set) var ownedDecorationIds: [String] = []
    @Published var selectedDecorationId: String = "classic"
    @Published private(set) var gachaTickets: Int = 0

    @Published var lastMessage: String? = nil

    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase

    init(get: GetMyProfileUseCase, update: UpdateMyProfileUseCase) {
        self.get = get
        self.update = update
    }

    // MARK: - Catalog (App側で定義。ID文字列はShareCard側でも使う)

    struct Decoration: Identifiable, Equatable {
        let id: String
        let name: String
        let rarity: Rarity
        let weight: Int
    }

    enum Rarity: String, CaseIterable {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"
    }

    // “classic” は初期付与で必ず所持
    private let catalog: [Decoration] = [
        .init(id: "classic", name: "Classic", rarity: .common, weight: 0),

        .init(id: "sakura", name: "Sakura", rarity: .common, weight: 55),
        .init(id: "aurora", name: "Aurora", rarity: .rare, weight: 28),
        .init(id: "neon", name: "Neon", rarity: .epic, weight: 14),
        .init(id: "gold", name: "Gold", rarity: .legendary, weight: 3),
    ]

    var ownedDecorations: [Decoration] {
        let map = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        // classic を必ず表示
        let ids = Array(Set(ownedDecorationIds + ["classic"]))
        return ids.compactMap { map[$0] }.sorted { a, b in
            // rarity順 + 名前順（任意）
            let ra = rank(a.rarity), rb = rank(b.rarity)
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }

    func ratesTextByRarity() -> [String] {
        let pool = catalog.filter { $0.weight > 0 }
        let sum = pool.reduce(0) { $0 + $1.weight }
        guard sum > 0 else { return [] }

        var buckets: [Rarity: Int] = [:]
        for d in pool { buckets[d.rarity, default: 0] += d.weight }

        return Rarity.allCases.compactMap { r in
            guard let w = buckets[r], w > 0 else { return nil }
            let pct = Double(w) / Double(sum) * 100.0
            return "\(r.rawValue): \(String(format: "%.1f", pct))%"
        }
    }

    private func rank(_ r: Rarity) -> Int {
        switch r {
        case .legendary: return 0
        case .epic: return 1
        case .rare: return 2
        case .common: return 3
        }
    }

    // MARK: - Load / Save

    func load() {
        let p = get()
        userId = p.userId
        displayName = p.displayName

        ownedDecorationIds = p.ownedDecorationIds
        selectedDecorationId = p.selectedDecorationId
        gachaTickets = p.gachaTickets
    }

    func save() {
        let p = update(displayName: displayName)
        userId = p.userId
        displayName = p.displayName

        ownedDecorationIds = p.ownedDecorationIds
        selectedDecorationId = p.selectedDecorationId
        gachaTickets = p.gachaTickets
    }

    // MARK: - Decoration ops

    func selectDecoration(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard ownedDecorationIds.contains(trimmed) || trimmed == "classic" else {
            lastMessage = "未所持の装飾は選べません"
            return
        }

        let p = update(selectedDecorationId: trimmed)
        selectedDecorationId = p.selectedDecorationId
        lastMessage = "装飾を「\(displayNameForDecoration(trimmed))」に変更しました"
    }

    func drawFreeGacha() {
        guard gachaTickets > 0 else {
            lastMessage = "無料ガチャ券がありません"
            return
        }

        // 1) 消費
        _ = update(gachaTickets: gachaTickets - 1)
        gachaTickets -= 1

        // 2) 抽選（classic除外 + weight>0 のみ）
        let pool = catalog.filter { $0.weight > 0 }
        guard let hit = weightedPick(pool) else {
            lastMessage = "ガチャ抽選に失敗しました"
            return
        }

        // 3) 付与（重複なら“同じのが出た”扱い。ここは後で欠片などにしても良い）
        var owned = Set(ownedDecorationIds + ["classic"])
        let isNew = !owned.contains(hit.id)
        owned.insert(hit.id)

        let newOwned = Array(owned)
        let p = update(ownedDecorationIds: newOwned)

        ownedDecorationIds = p.ownedDecorationIds

        if isNew {
            // 新規獲得時は自動で選択しても良い（好み）
            let p2 = update(selectedDecorationId: hit.id)
            selectedDecorationId = p2.selectedDecorationId
            lastMessage = "🎉 新しい装飾「\(hit.name)」を獲得しました（自動で適用）"
        } else {
            lastMessage = "「\(hit.name)」が出ました（重複）"
        }
    }

    private func weightedPick(_ items: [Decoration]) -> Decoration? {
        let sum = items.reduce(0) { $0 + max(0, $1.weight) }
        guard sum > 0 else { return nil }
        var r = Int.random(in: 0..<sum)
        for it in items {
            let w = max(0, it.weight)
            if r < w { return it }
            r -= w
        }
        return items.last
    }

    func displayNameForDecoration(_ id: String) -> String {
        if id == "classic" { return "Classic" }
        return catalog.first(where: { $0.id == id })?.name ?? id
    }
}
