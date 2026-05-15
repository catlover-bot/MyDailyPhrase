import Foundation
import Combine
import Domain
import OSLog
import Presentation

@MainActor
final class GachaViewModel: ObservableObject {

    struct GachaBanner: Codable, Hashable, Sendable {
        var title: String
        var subtitle: String
        var note: String
        var featuredIds: [String]
    }

    struct WeightRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    struct ItemWeightRow: Identifiable {
        let id: String
        let name: String
        let rarity: String
        let value: String
        let isFeatured: Bool
    }

    enum SeasonTheme: String, CaseIterable, Identifiable, Sendable {
        case space
        case japanese
        case neon

        var id: String { rawValue }

        var title: String {
            switch self {
            case .space:
                return "宇宙"
            case .japanese:
                return "和風"
            case .neon:
                return "ネオン"
            }
        }

        var featuredGachaIDs: [String] {
            switch self {
            case .space:
                return ["stardust", "nebula", "nova"]
            case .japanese:
                return ["sakura", "paper", "gold"]
            case .neon:
                return ["neon", "hologram", "arcade"]
            }
        }
    }

    struct SeasonMilestoneReward: Identifiable, Hashable, Sendable {
        let id: Int
        let title: String
        let targetOwnedCount: Int
        let ticketReward: Int
        let shardReward: Int
    }

    struct SeasonMilestoneRow: Identifiable, Sendable {
        let reward: SeasonMilestoneReward
        let currentOwnedCount: Int
        let isClaimed: Bool

        var id: Int { reward.id }

        var isClaimable: Bool {
            !isClaimed && currentOwnedCount >= reward.targetOwnedCount
        }

        var progressText: String {
            "\(min(currentOwnedCount, reward.targetOwnedCount))/\(reward.targetOwnedCount)"
        }

        var rewardText: String {
            "チケット+\(reward.ticketReward) / 欠片+\(reward.shardReward)"
        }
    }

    struct StateSummary {
        let label: String
        let detail: String
    }

    struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
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

    enum State: Equatable {
        case idle
        case spinning
        case result(GachaDrawSummary)
        case error(String)
    }

    private enum ExchangeOutcome: Sendable {
        case success(decorationId: String, name: String, cost: Int)
        case failure(String)
    }

    private struct SpinMarker: Codable, Sendable {
        let drawId: String
        let count: Int
        let startedAt: TimeInterval
    }

    @Published var currentBanner: GachaBanner = .init(
        title: "今週のピックアップ",
        subtitle: "無料ガチャ + 欠片交換 + シーズン報酬",
        note: "今週は光や星空モチーフのテーマが少し出やすくなっています。週次ミッションでは限定のしるし系デコも獲得できます。",
        featuredIds: ["hologram", "stardust", "royal"]
    )

    @Published private(set) var state: State = .idle

    @Published private(set) var tickets: Int = 0
    @Published private(set) var shards: Int = 0
    @Published private(set) var pity: Int = 0

    @Published private(set) var selectedDecorationId: String = CardDecorationCatalog.classicId
    @Published private(set) var ownedCounts: [String: Int] = [CardDecorationCatalog.classicId: 1]
    @Published private(set) var ownedRecords: [String: OwnedDecorationRecord] = [
        CardDecorationCatalog.classicId: OwnedDecorationRecord(
            acquisitionDate: .distantPast,
            source: .defaultItem,
            count: 1
        )
    ]
    @Published private(set) var profileDisplayName: String = "Me"
    @Published private(set) var profileUserId: String = "-"
    @Published private(set) var hasUnlimitedTickets: Bool = false
    @Published private(set) var seasonTheme: SeasonTheme = .space
    @Published private(set) var seasonWeekKey: String = "-"
    @Published private(set) var seasonMilestoneClaimedIDs: Set<Int> = []

    @Published private(set) var actionMessage: String? = nil
    @Published var lastMessage: String? = nil
    @Published private(set) var history: [HistoryItem] = []
    @Published private(set) var stateAuditTrail: [String] = []

    let historyLimit: Int = 30
    let pityMax: Int = 80

    private let featuredMultiplier: Double = 1.8

    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
    private let drawDecorationGacha: DrawDecorationGachaUseCase
    private let grantDailyFreeTicket: GrantDailyFreeTicketUseCase
    private let hasUnlimitedTicketsForUserId: (String) -> Bool
    private let forceDrawErrorOnceForUITest: Bool

    private let historyDefaults: UserDefaults
    private let historyKey = "MyDailyPhrase.gacha.history.v1"
    private let spinMarkerKey = "MyDailyPhrase.gacha.spin.marker.v1"
    private let seasonMilestoneClaimsBaseKey = "MyDailyPhrase.gacha.seasonMilestone.claimed.v1"
    private let logger = Logger(subsystem: "jp.catloverbot.MyDailyPhrase", category: "GachaViewModel")
    private let ioWorker = GachaIOWorker()

    private var drawTask: Task<Void, Never>? = nil
    private var drawTimeoutTask: Task<Void, Never>? = nil
    private var runningDrawID: UUID? = nil
    private var pendingDrawSummary: GachaDrawSummary? = nil
    private var runningActionID: UUID? = nil
    private var refreshTask: Task<Void, Never>? = nil
    private var refreshQueued = false
    private var spinFailSafeTask: Task<Void, Never>? = nil
    private var spinStateEnteredAt: Date? = nil
    private var auditSequence: Int = 0
    private var didInjectUITestDrawError = false
    private var lastPublishedSeasonMilestoneDigest: String? = nil

    private let actionTimeoutNanoseconds: UInt64 = 5_000_000_000
    private let drawTimeoutNanoseconds: UInt64 = 5_000_000_000
    private let stateAuditLimit: Int = 80

    init(
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase,
        drawDecorationGacha: DrawDecorationGachaUseCase,
        grantDailyFreeTicket: GrantDailyFreeTicketUseCase,
        hasUnlimitedTicketsForUserId: @escaping (String) -> Bool = { _ in false },
        forceDrawErrorOnceForUITest: Bool = false,
        historyDefaults: UserDefaults = .standard
    ) {
        self.getMyProfile = getMyProfile
        self.updateMyProfile = updateMyProfile
        self.drawDecorationGacha = drawDecorationGacha
        self.grantDailyFreeTicket = grantDailyFreeTicket
        self.hasUnlimitedTicketsForUserId = hasUnlimitedTicketsForUserId
        self.forceDrawErrorOnceForUITest = forceDrawErrorOnceForUITest
        self.historyDefaults = historyDefaults

        refreshSeasonThemeContext()
        loadHistory()
        appendStateAudit("init state=\(stateLabel(state))")
    }

    var isSpinning: Bool {
        if case .spinning = state { return true }
        return false
    }

    var isActionRunning: Bool {
        runningActionID != nil
    }

    var isBusy: Bool {
        isSpinning || isActionRunning
    }

    var currentResult: GachaDrawSummary? {
        if case .result(let s) = state { return s }
        return nil
    }

    var allDecorations: [CardDecoration] { CardDecorationCatalog.all }
    var allDecorationItems: [DecorationItem] { CardDecorationCatalog.items }

    private var seasonLimitedCatalog: [CardDecoration] {
        CardDecorationCatalog.all.filter { CardDecorationCatalog.isSeasonLimited($0.id) }
    }

    var seasonLimitedTotalCount: Int {
        seasonLimitedCatalog.count
    }

    var seasonLimitedOwnedCount: Int {
        seasonLimitedCatalog.reduce(into: 0) { partialResult, item in
            if isOwned(item.id) {
                partialResult += 1
            }
        }
    }

    var seasonLimitedCollectionRate: Double {
        guard seasonLimitedTotalCount > 0 else { return 0.0 }
        return Double(seasonLimitedOwnedCount) / Double(seasonLimitedTotalCount)
    }

    var seasonLimitedCollectionProgressText: String {
        "限定デコ収集 \(seasonLimitedOwnedCount)/\(seasonLimitedTotalCount)"
    }

    var seasonLimitedOwnedDecorations: [(item: CardDecoration, count: Int)] {
        ownedDecorations.filter { CardDecorationCatalog.isSeasonLimited($0.item.id) }
    }

    var seasonRewardPreviewRows: [String] {
        let tiers = ["bronze", "silver", "gold"]
        return tiers.compactMap { tier in
            let names = CardDecorationCatalog
                .seasonRewardCandidates(tierRaw: tier)
                .map(\.name)
            guard !names.isEmpty else { return nil }
            return "\(tier.uppercased()): \(names.joined(separator: " / "))"
        }
    }

    var seasonThemePickupPreviewText: String {
        let names = seasonTheme.featuredGachaIDs.compactMap { CardDecorationCatalog.byId($0)?.name }
        return names.joined(separator: " / ")
    }

    var seasonThemeTitleText: String {
        "今週テーマ: \(seasonTheme.title) (\(seasonWeekKey))"
    }

    private var seasonMilestoneRewards: [SeasonMilestoneReward] {
        switch seasonTheme {
        case .space:
            return [
                .init(id: 1, title: "宇宙コレクター I", targetOwnedCount: 3, ticketReward: 3, shardReward: 60),
                .init(id: 2, title: "宇宙コレクター II", targetOwnedCount: 6, ticketReward: 6, shardReward: 130),
                .init(id: 3, title: "宇宙コレクター III", targetOwnedCount: 9, ticketReward: 10, shardReward: 240)
            ]
        case .japanese:
            return [
                .init(id: 1, title: "和の記録 I", targetOwnedCount: 3, ticketReward: 3, shardReward: 70),
                .init(id: 2, title: "和の記録 II", targetOwnedCount: 6, ticketReward: 6, shardReward: 140),
                .init(id: 3, title: "和の記録 III", targetOwnedCount: 9, ticketReward: 10, shardReward: 250)
            ]
        case .neon:
            return [
                .init(id: 1, title: "ネオン収集 I", targetOwnedCount: 3, ticketReward: 4, shardReward: 80),
                .init(id: 2, title: "ネオン収集 II", targetOwnedCount: 6, ticketReward: 7, shardReward: 150),
                .init(id: 3, title: "ネオン収集 III", targetOwnedCount: 9, ticketReward: 11, shardReward: 260)
            ]
        }
    }

    var seasonMilestoneRows: [SeasonMilestoneRow] {
        let currentOwned = seasonLimitedOwnedCount
        return seasonMilestoneRewards.map { reward in
            SeasonMilestoneRow(
                reward: reward,
                currentOwnedCount: currentOwned,
                isClaimed: seasonMilestoneClaimedIDs.contains(reward.id)
            )
        }
    }

    var hasClaimableSeasonMilestoneRewards: Bool {
        seasonMilestoneRows.contains { $0.isClaimable }
    }

    var seasonMilestoneSummaryText: String {
        let rows = seasonMilestoneRows
        guard !rows.isEmpty else {
            return "シーズン収集ミッションを準備中です"
        }

        let claimedCount = rows.filter(\.isClaimed).count
        if hasClaimableSeasonMilestoneRewards {
            return "受け取り可能な収集ミッション報酬があります"
        }
        if let next = rows.first(where: { !$0.isClaimed }) {
            let remain = max(0, next.reward.targetOwnedCount - seasonLimitedOwnedCount)
            return "次の報酬まで限定デコあと\(remain)個"
        }
        return "収集ミッション \(claimedCount)/\(rows.count) をすべて受取済み"
    }

    var nextSeasonMilestoneRemainingCount: Int? {
        guard let next = seasonMilestoneRows.first(where: { !$0.isClaimed }) else { return nil }
        return max(0, next.reward.targetOwnedCount - seasonLimitedOwnedCount)
    }

    var exchangeCandidates: [CardDecoration] {
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

    func itemMetadata(for id: String) -> DecorationItem? {
        CardDecorationCatalog.item(for: id)
    }

    func isOwned(_ id: String) -> Bool {
        (ownedCounts[id] ?? 0) > 0
    }

    func ownedCount(for id: String) -> Int {
        max(0, ownedCounts[id] ?? 0)
    }

    func isSeasonLimited(_ id: String) -> Bool {
        CardDecorationCatalog.isSeasonLimited(id)
    }

    func ownedRecord(for id: String) -> OwnedDecorationRecord? {
        ownedRecords[id]
    }

    func isSelected(_ id: String) -> Bool {
        selectedDecorationId == id
    }

    var pityText: String {
        "天井: \(pity)/\(pityMax)"
    }

    func canDraw(count: Int) -> Bool {
        (hasUnlimitedTickets || tickets >= count) && !isBusy
    }

    var weightTable: [WeightRow] {
        GachaOddsPolicy.rarityOdds(pool: CardDecorationCatalog.pool).map { row in
            WeightRow(
                label: GachaThemePresentation.rarityLabel(for: row.rarity),
                value: String(format: "%.1f%%", row.probability * 100.0)
            )
        }
    }

    var itemWeightTable: [ItemWeightRow] {
        GachaOddsPolicy.itemOdds(
            pool: CardDecorationCatalog.pool,
            pickupMultipliers: pickupMultipliers
        )
            .sorted { lhs, rhs in
                if lhs.item.rarity.rank != rhs.item.rarity.rank {
                    return lhs.item.rarity.rank > rhs.item.rarity.rank
                }
                return lhs.item.name < rhs.item.name
            }
            .map { row in
                return ItemWeightRow(
                    id: row.item.id,
                    name: row.item.name,
                    rarity: GachaThemePresentation.rarityLabel(for: row.item.rarity),
                    value: String(format: "%.2f%%", row.probability * 100.0),
                    isFeatured: row.isFeatured
                )
            }
    }

    var oddsNotes: [String] {
        var notes = [
            "現在のLEGENDARY率（目安）: \(currentLegendaryRateText)",
            "※表示は通常時の重み比率です",
            "※天井 / ソフト天井 / 10連保証により実際の当選率は変動します"
        ]
        if pity >= (pityMax - 1) {
            notes.insert("※次の1回は天井でLEGENDARY確定です", at: 1)
        }
        return notes
    }

    var stateSummary: StateSummary {
        switch state {
        case .idle:
            return .init(label: "準備完了", detail: "無料ガチャやチケットを選べます")
        case .spinning:
            return .init(label: "抽選中", detail: "結果を準備しています")
        case .result(let summary):
            return .init(label: "結果", detail: "\(summary.drawn.count)件の結果を確認できます")
        case .error(let message):
            return .init(label: "エラー", detail: message)
        }
    }

    var currentErrorText: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }

    var currentLegendaryRateText: String {
        if pity >= (pityMax - 1) {
            return "100.00%"
        }

        let multipliers = pickupMultipliers
        let pct = (GachaOddsPolicy.rarityOdds(
            pool: CardDecorationCatalog.pool,
            pickupMultipliers: multipliers,
            pityCount: pity
        )
        .first(where: { $0.rarity == .legendary })?
        .probability ?? 0) * 100.0
        return String(format: "%.2f%%", pct)
    }

    var untilPityText: String {
        let remain = max(0, pityMax - pity)
        return remain == 0 ? "次回天井確定" : "天井まであと\(remain)回"
    }

    var diagnosticsSummaryLines: [String] {
        [
            "state: \(stateSummary.label)",
            "tickets/shards/pity: \(tickets)/\(shards)/\(pity)",
            "drawID: \(runningDrawID?.uuidString ?? "-")",
            "drawTask: \(drawTask == nil ? "0" : "1") / timeout: \(drawTimeoutTask == nil ? "0" : "1")",
            "pendingSummary: \(pendingDrawSummary == nil ? "0" : "1")",
            "actionRunning: \(runningActionID == nil ? "0" : "1")",
            "refreshTask: \(refreshTask == nil ? "0" : "1") / queued: \(refreshQueued ? "1" : "0")"
        ]
    }

    var latestStateAudits: [String] {
        Array(stateAuditTrail.suffix(24).reversed())
    }

    var stateAuditExportText: String {
        let now = ISO8601DateFormatter().string(from: Date())
        let header = [
            "Gacha Audit Export",
            "time: \(now)",
            "user: \(profileDisplayName) / \(profileUserId)",
            "summary: \(diagnosticsSummaryLines.joined(separator: " | "))",
            "----"
        ].joined(separator: "\n")

        return ([header] + stateAuditTrail).joined(separator: "\n")
    }

    func clearStateAudits() {
        stateAuditTrail = []
        auditSequence = 0
        appendStateAudit("audit cleared")
    }

    func recoverNow() {
        drawTask?.cancel()
        drawTask = nil
        drawTimeoutTask?.cancel()
        drawTimeoutTask = nil
        runningDrawID = nil
        pendingDrawSummary = nil
        clearSpinMarker(reason: "recoverNow")
        runningActionID = nil
        actionMessage = nil
        transition(to: .idle, reason: "recoverNow")
        lastMessage = "状態を再同期しました"
        scheduleRefreshProfile()
    }

    func clearError() {
        if case .error = state {
            transition(to: .idle, reason: "clearError")
        }
    }

    private static func legendaryBoostMultiplier(pityCount: Int) -> Double {
        GachaOddsPolicy.legendaryBoostMultiplier(pityCount: pityCount)
    }

    private func refreshSeasonThemeContext(referenceDate: Date = Date()) {
        let weekKey = Self.currentSeasonWeekKey(for: referenceDate)
        let theme = Self.seasonTheme(for: weekKey)
        let hasChanged = (seasonWeekKey != weekKey) || (seasonTheme != theme)
        seasonWeekKey = weekKey
        seasonTheme = theme
        if hasChanged || currentBanner.featuredIds != theme.featuredGachaIDs {
            updateBanner(theme: theme, weekKey: weekKey)
            appendStateAudit("season theme=\(theme.rawValue) week=\(weekKey)")
        }
    }

    private func updateBanner(theme: SeasonTheme, weekKey: String) {
        currentBanner = .init(
            title: "週替わりテーマ（重み付き）",
            subtitle: "\(theme.title)シーズン \(weekKey) / 天井 + 欠片 + 限定報酬",
            note: "今週のテーマは「\(theme.title)」。限定デコを集めると週次収集報酬が受け取れます。",
            featuredIds: theme.featuredGachaIDs
        )
    }

    private static func seasonTheme(for weekKey: String) -> SeasonTheme {
        let themes = SeasonTheme.allCases
        guard !themes.isEmpty else { return .space }
        let index = Int(stableHash64(weekKey) % UInt64(themes.count))
        return themes[index]
    }

    private static func currentSeasonWeekKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private static func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private var pickupMultipliers: [String: Double] {
        Dictionary(uniqueKeysWithValues: currentBanner.featuredIds.map { ($0, featuredMultiplier) })
    }

    func load() {
        refreshSeasonThemeContext()
        recoverFromPersistedSpinMarkerIfNeeded()
        scheduleRefreshProfile()
    }

    func drawOnce() {
        spin(count: 1)
    }

    func drawTen() {
        spin(count: 10)
    }

    func closeResult() {
        drawTask?.cancel()
        drawTask = nil
        drawTimeoutTask?.cancel()
        drawTimeoutTask = nil
        runningDrawID = nil
        pendingDrawSummary = nil
        clearSpinMarker(reason: "closeResult")
        transition(to: .idle, reason: "closeResult")
        lastMessage = nil
    }

    func selectDecoration(id: String) {
        guard !isSpinning else {
            lastMessage = "抽選中は装飾変更できません"
            return
        }
        guard !isActionRunning else {
            lastMessage = "処理中です。少し待ってください"
            return
        }
        guard isOwned(id) else {
            transition(to: .error("未所持の装飾です"), reason: "selectDecoration not owned")
            lastMessage = "未所持の装飾です"
            return
        }

        let actionID = beginAction(message: "装飾を変更中…")

        let update = updateMyProfile
        let timeoutNs = actionTimeoutNanoseconds

        Task { [weak self] in
            guard let self else { return }

            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await MainActor.run {
                    guard let self else { return }
                    self.failActionIfStillRunning(
                        id: actionID,
                        message: "装飾変更がタイムアウトしました。もう一度お試しください"
                    )
                }
            }

            _ = await self.ioWorker.run {
                update(selectedDecorationId: id)
            }
            timeoutTask.cancel()

            guard self.finishActionIfStillRunning(id: actionID) else { return }

            self.selectedDecorationId = id
            self.lastMessage = "「\(CardDecorationCatalog.byId(id)?.name ?? id)」を装備しました"
            self.scheduleRefreshProfile()
        }
    }

    func grantDailyTicketIfNeeded() {
        guard !isSpinning else {
            lastMessage = "抽選中は無料券確認できません"
            return
        }
        guard !isActionRunning else {
            lastMessage = "処理中です。少し待ってください"
            return
        }

        let actionID = beginAction(message: "無料券を確認中…")

        let grant = grantDailyFreeTicket
        let timeoutNs = actionTimeoutNanoseconds

        Task { [weak self] in
            guard let self else { return }

            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await MainActor.run {
                    guard let self else { return }
                    self.failActionIfStillRunning(
                        id: actionID,
                        message: "無料券処理がタイムアウトしました。もう一度お試しください"
                    )
                }
            }

            let grantedCount = await self.ioWorker.run { () -> Int in
                grant.grantedTicketCountIfNeeded()
            }
            timeoutTask.cancel()

            guard self.finishActionIfStillRunning(id: actionID) else { return }

            if grantedCount > 0 {
                self.tickets += grantedCount
                if grantedCount > 1 {
                    self.lastMessage = "本日の無料券を受け取りました（+\(grantedCount)）"
                } else {
                    self.lastMessage = "本日の無料券を受け取りました"
                }
                self.appendSecurityAudit(
                    kind: .gachaDailyTicketGranted,
                    title: "デイリー無料券受領",
                    detail: "tickets=\(self.tickets) granted=\(grantedCount)"
                )
            } else {
                self.lastMessage = "本日の無料券は受け取り済みです"
            }
            self.scheduleRefreshProfile()
        }
    }

    func claimSeasonMilestoneRewards() {
        guard !isSpinning else {
            lastMessage = "抽選中はシーズン報酬を受け取れません"
            return
        }
        guard !isActionRunning else {
            lastMessage = "処理中です。少し待ってください"
            return
        }

        let claimable = seasonMilestoneRows.filter { $0.isClaimable }
        guard !claimable.isEmpty else {
            lastMessage = "受け取り可能なシーズン収集報酬はありません"
            return
        }

        let claimedIds = claimable.map(\.id)
        let ticketGain = claimable.reduce(0) { $0 + $1.reward.ticketReward }
        let shardGain = claimable.reduce(0) { $0 + $1.reward.shardReward }
        let actionID = beginAction(message: "シーズン収集報酬を受け取り中…")
        let actorHint = profileUserId.isEmpty || profileUserId == "-" ? nil : String(profileUserId.suffix(8))
        let auditEvent = SecurityAuditEvent(
            category: .gacha,
            kind: .gachaSeasonMilestoneClaimed,
            title: "シーズン収集報酬受取",
            detail: "milestones=\(claimedIds.map(String.init).joined(separator: ",")) limitedOwned=\(seasonLimitedOwnedCount) tickets+\(ticketGain) shards+\(shardGain)",
            actorHint: actorHint
        )

        let update = updateMyProfile
        let timeoutNs = actionTimeoutNanoseconds

        Task { [weak self] in
            guard let self else { return }

            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await MainActor.run {
                    guard let self else { return }
                    self.failActionIfStillRunning(
                        id: actionID,
                        message: "シーズン収集報酬処理がタイムアウトしました。もう一度お試しください"
                    )
                }
            }

            _ = await self.ioWorker.run {
                update(
                    appendSecurityAuditEvent: auditEvent,
                    addGachaTickets: ticketGain,
                    addDecorationShards: shardGain
                )
            }
            timeoutTask.cancel()

            guard self.finishActionIfStillRunning(id: actionID) else { return }

            self.tickets += ticketGain
            self.shards += shardGain
            self.seasonMilestoneClaimedIDs.formUnion(claimedIds)
            self.persistSeasonMilestoneClaims(for: self.profileUserId, weekKey: self.seasonWeekKey)
            self.lastMessage = "シーズン収集報酬を受け取りました（チケット+\(ticketGain) / 欠片+\(shardGain)）"
            self.publishSeasonMilestoneUpdateIfNeeded(force: true)
            self.scheduleRefreshProfile()
        }
    }

    func exchangeCost(for decoration: CardDecoration) -> Int {
        Self.exchangeCost(for: decoration.rarity)
    }

    func exchange(decorationId: String) {
        guard !isSpinning else {
            lastMessage = "抽選中は交換できません"
            return
        }
        guard !isActionRunning else {
            lastMessage = "処理中です。少し待ってください"
            return
        }

        let actionID = beginAction(message: "交換処理中…")

        let get = getMyProfile
        let update = updateMyProfile
        let timeoutNs = actionTimeoutNanoseconds

        Task { [weak self] in
            guard let self else { return }

            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNs)
                await MainActor.run {
                    guard let self else { return }
                    self.failActionIfStillRunning(
                        id: actionID,
                        message: "交換処理がタイムアウトしました。もう一度お試しください"
                    )
                }
            }

            let outcome = await self.ioWorker.run { () -> ExchangeOutcome in
                guard let item = CardDecorationCatalog.byId(decorationId) else {
                    return .failure("不明なアイテムです")
                }

                let cost = Self.exchangeCost(for: item.rarity)
                let p = get()

                guard p.decorationShards >= cost else {
                    return .failure("欠片が足りません（\(cost)必要）")
                }

                var counts = p.ownedDecorationCounts
                counts[CardDecorationCatalog.classicId] = max(1, counts[CardDecorationCatalog.classicId] ?? 1)
                counts[item.id, default: 0] += 1
                var records = p.ownedDecorationRecords
                let existingRecord = records[item.id]
                records[item.id] = OwnedDecorationRecord(
                    acquisitionDate: existingRecord?.acquisitionDate ?? Date(),
                    source: existingRecord?.source ?? .exchange,
                    count: counts[item.id] ?? 1
                )

                _ = update(
                    ownedDecorationCounts: counts,
                    ownedDecorationRecords: records,
                    decorationShards: max(0, p.decorationShards - cost)
                )
                return .success(decorationId: item.id, name: item.name, cost: cost)
            }
            timeoutTask.cancel()

            guard self.finishActionIfStillRunning(id: actionID) else { return }

            switch outcome {
            case .success(let decorationId, let name, let cost):
                var counts = self.ownedCounts
                counts[CardDecorationCatalog.classicId] = max(1, counts[CardDecorationCatalog.classicId] ?? 1)
                counts[decorationId, default: 0] += 1
                self.ownedCounts = counts
                let previousRecord = self.ownedRecords[decorationId]
                self.ownedRecords[decorationId] = OwnedDecorationRecord(
                    acquisitionDate: previousRecord?.acquisitionDate ?? Date(),
                    source: previousRecord?.source ?? .exchange,
                    count: counts[decorationId] ?? 1
                )
                self.shards = max(0, self.shards - cost)
                self.lastMessage = "交換: 「\(name)」 (欠片-\(cost))"
                self.appendSecurityAudit(
                    kind: .gachaExchangeCompleted,
                    title: "交換成功",
                    detail: "item=\(decorationId) name=\(name) cost=\(cost) shards=\(self.shards)"
                )
                self.scheduleRefreshProfile()
            case .failure(let message):
                self.lastMessage = message
                self.appendSecurityAudit(
                    kind: .gachaExchangeFailed,
                    severity: .warning,
                    title: "交換失敗",
                    detail: message
                )
            }
        }
    }

    func clearHistory() {
        history = []
        persistHistoryAsync(history)
        lastMessage = "履歴をクリアしました"
    }

    private func beginAction(message: String) -> UUID {
        let id = UUID()
        runningActionID = id
        actionMessage = message
        debugLog("action begin id=\(id.uuidString) msg=\(message)")
        return id
    }

    @discardableResult
    private func finishActionIfStillRunning(id: UUID) -> Bool {
        guard runningActionID == id else { return false }
        runningActionID = nil
        actionMessage = nil
        debugLog("action finish id=\(id.uuidString)")
        return true
    }

    private func failActionIfStillRunning(id: UUID, message: String) {
        guard runningActionID == id else { return }
        runningActionID = nil
        actionMessage = nil
        transition(to: .error(message), reason: "action timeout id=\(id.uuidString)")
        lastMessage = message
        debugLog("action timeout id=\(id.uuidString) msg=\(message)")
        scheduleRefreshProfile()
    }

    private func beginDraw(count: Int) -> UUID {
        let id = UUID()
        pauseRefreshForSpin()
        runningDrawID = id
        pendingDrawSummary = nil
        persistSpinMarker(drawID: id, count: count)
        transition(to: .spinning, reason: "beginDraw id=\(id.uuidString)")
        debugLog("draw begin id=\(id.uuidString)")
        let timeoutNs = drawTimeoutNanoseconds

        drawTimeoutTask?.cancel()
        drawTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNs)
            await MainActor.run {
                guard let self else { return }
                guard self.runningDrawID == id else { return }
                self.debugLog("draw timeout id=\(id.uuidString)")
                self.drawTask?.cancel()
                self.drawTask = nil
                self.drawTimeoutTask = nil
                self.runningDrawID = nil
                let msg = "ガチャ処理がタイムアウトしました。状態を再取得します"
                self.transition(to: .error(msg), reason: "draw timeout id=\(id.uuidString)")
                self.lastMessage = msg
                self.appendSecurityAudit(
                    kind: .gachaDrawFailed,
                    severity: .error,
                    title: "ガチャ抽選タイムアウト",
                    detail: "drawId=\(id.uuidString)"
                )
                self.scheduleRefreshProfile()
            }
        }

        return id
    }

    @discardableResult
    private func completeDrawIfCurrent(id: UUID) -> Bool {
        guard runningDrawID == id else {
            appendStateAudit("draw stale result id=\(id.uuidString)")
            debugLog("draw stale result ignored id=\(id.uuidString)")
            return false
        }

        runningDrawID = nil
        drawTimeoutTask?.cancel()
        drawTimeoutTask = nil
        drawTask = nil
        clearSpinMarker(reason: "draw complete id=\(id.uuidString)")
        appendStateAudit("draw finish id=\(id.uuidString)")
        debugLog("draw finish id=\(id.uuidString)")
        return true
    }

    private func spin(count: Int) {
        guard !isBusy else {
            lastMessage = "処理中です。完了までお待ちください"
            return
        }

        guard hasUnlimitedTickets || tickets >= count else {
            transition(to: .error("チケットが足りません（\(count)必要）"), reason: "draw insufficient tickets")
            lastMessage = "チケットが足りません（\(count)必要）"
            appendSecurityAudit(
                kind: .gachaDrawFailed,
                severity: .warning,
                title: "ガチャ抽選失敗",
                detail: "チケット不足 count=\(count) tickets=\(tickets)"
            )
            return
        }

        let drawID = beginDraw(count: count)
        appendSecurityAudit(
            kind: .gachaDrawStarted,
            title: "ガチャ抽選開始",
            detail: "count=\(count) tickets=\(tickets) pity=\(pity)"
        )

        let draw = drawDecorationGacha
        let multipliers = pickupMultipliers

        drawTask?.cancel()
        drawTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            if self.forceDrawErrorOnceForUITest && !self.didInjectUITestDrawError {
                self.didInjectUITestDrawError = true
                try? await Task.sleep(nanoseconds: 180_000_000)
                if Task.isCancelled { return }
                guard self.completeDrawIfCurrent(id: drawID) else { return }
                let message = "UI Test: 強制失敗（復帰確認用）"
                self.transition(to: .error(message), reason: "uitest forced draw error")
                self.lastMessage = message
                self.appendSecurityAudit(
                    kind: .gachaDrawFailed,
                    severity: .error,
                    title: "ガチャ抽選失敗（UIテスト注入）",
                    detail: "drawId=\(drawID.uuidString)"
                )
                return
            }

            // 演出が視認できる最小待機
            try? await Task.sleep(nanoseconds: 250_000_000)
            let ioStartedAt = Date()
            let summary = await self.ioWorker.run {
                draw(count: count, pickupMultipliers: multipliers)
            }
            let ioElapsedMs = Int(Date().timeIntervalSince(ioStartedAt) * 1000.0)
            self.appendStateAudit("draw io done ms=\(ioElapsedMs)")

            if Task.isCancelled { return }
            guard self.completeDrawIfCurrent(id: drawID) else { return }

            self.pendingDrawSummary = summary

            guard !summary.drawn.isEmpty else {
                self.transition(to: .error("ガチャ結果の反映に失敗しました"), reason: "empty draw summary")
                self.lastMessage = "ガチャ結果の反映に失敗しました"
                self.debugLog("state -> error empty summary")
                self.appendSecurityAudit(
                    kind: .gachaDrawFailed,
                    severity: .error,
                    title: "ガチャ抽選失敗",
                    detail: "結果が空でした count=\(count)"
                )
                return
            }

            self.applyDrawSummaryLocally(summary, drawCount: count)
            self.transition(to: .result(summary), reason: "draw completed id=\(drawID.uuidString)")
            self.debugLog("state -> result drawn=\(summary.drawn.count)")

            let gotNames = summary.drawn.map { $0.name }.joined(separator: ", ")
            let shardMsg = summary.shardsGained > 0 ? " / 欠片+\(summary.shardsGained)" : ""
            self.lastMessage = "獲得: \(gotNames)\(shardMsg)"
            self.appendSecurityAudit(
                kind: .gachaDrawCompleted,
                title: "ガチャ抽選完了",
                detail: "count=\(summary.drawn.count) new=\(summary.newIds.count) shards+\(summary.shardsGained) pity=\(summary.pityAfter)"
            )

            self.appendHistory(from: summary)
            self.scheduleRefreshProfile()
        }
    }

    private func applyProfile(_ p: UserProfile) {
        refreshSeasonThemeContext()
        hasUnlimitedTickets = hasUnlimitedTicketsForUserId(p.userId)
        tickets = p.gachaTickets
        shards = p.decorationShards
        pity = p.pityCount
        selectedDecorationId = p.selectedDecorationId
        profileDisplayName = p.displayName
        profileUserId = p.userId
        seasonMilestoneClaimedIDs = loadSeasonMilestoneClaims(for: p.userId, weekKey: seasonWeekKey)
        ownedCounts = p.ownedDecorationCounts
        ownedRecords = p.ownedDecorationRecords
        if (ownedCounts[CardDecorationCatalog.classicId] ?? 0) <= 0 {
            ownedCounts[CardDecorationCatalog.classicId] = 1
        }
        if ownedRecords[CardDecorationCatalog.classicId] == nil {
            ownedRecords[CardDecorationCatalog.classicId] = OwnedDecorationRecord(
                acquisitionDate: .distantPast,
                source: .defaultItem,
                count: 1
            )
        }
        publishSeasonMilestoneUpdateIfNeeded()
    }

    private func applyDrawSummaryLocally(_ summary: GachaDrawSummary, drawCount: Int) {
        if !hasUnlimitedTickets {
            tickets = max(0, tickets - max(1, drawCount))
        }
        shards = max(0, shards + summary.shardsGained)
        pity = summary.pityAfter

        var counts = ownedCounts
        counts[CardDecorationCatalog.classicId] = max(1, counts[CardDecorationCatalog.classicId] ?? 1)
        for item in summary.drawn {
            counts[item.id, default: 0] += 1
        }
        ownedCounts = counts

        var records = ownedRecords
        if records[CardDecorationCatalog.classicId] == nil {
            records[CardDecorationCatalog.classicId] = OwnedDecorationRecord(
                acquisitionDate: .distantPast,
                source: .defaultItem,
                count: 1
            )
        }
        let drawDate = Date()
        for item in summary.drawn {
            let existingRecord = records[item.id]
            records[item.id] = OwnedDecorationRecord(
                acquisitionDate: existingRecord?.acquisitionDate ?? drawDate,
                source: existingRecord?.source ?? .freeGacha,
                count: counts[item.id] ?? 1
            )
        }
        ownedRecords = records
    }

    func recoverFromStuckSpinIfNeeded() {
        guard case .spinning = state else { return }
        appendStateAudit("recover requested while spinning")
        debugLog("recover requested while spinning")

        if let summary = pendingDrawSummary, !summary.drawn.isEmpty {
            drawTask?.cancel()
            drawTask = nil
            drawTimeoutTask?.cancel()
            drawTimeoutTask = nil
            runningDrawID = nil
            transition(to: .result(summary), reason: "recoverFromStuckSpin with pending summary")
            debugLog("state -> result by recover drawn=\(summary.drawn.count)")
            return
        }

        if drawTask != nil {
            appendStateAudit("recover deferred draw still running")
            debugLog("recover deferred: draw still running")
            return
        }

        drawTimeoutTask?.cancel()
        drawTimeoutTask = nil
        runningDrawID = nil

        transition(to: .idle, reason: "recoverFromStuckSpin fallback idle")
        debugLog("state -> idle by recover")
        scheduleRefreshProfile()
    }

    private func scheduleRefreshProfile() {
        if case .spinning = state {
            refreshQueued = true
            appendStateAudit("refresh queued while spinning")
            return
        }

        if refreshTask != nil {
            refreshQueued = true
            return
        }

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }

            repeat {
                self.refreshQueued = false
                await self.refreshProfile()
            } while self.refreshQueued && !Task.isCancelled
        }
    }

    private func pauseRefreshForSpin() {
        guard refreshTask != nil else { return }
        refreshTask?.cancel()
        refreshTask = nil
        refreshQueued = true
        appendStateAudit("refresh paused for spinning")
    }

    private func refreshProfile() async {
        let get = getMyProfile
        let startedAt = Date()
        let profile = await ioWorker.run {
            get()
        }
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        if elapsedMs > 350 {
            appendStateAudit("refresh slow ms=\(elapsedMs)")
        }

        if Task.isCancelled { return }
        applyProfile(profile)
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

        persistHistoryAsync(history)
    }

    private func loadHistory() {
        guard let data = historyDefaults.data(forKey: historyKey) else { return }
        if let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = items
        }
    }

    private func persistHistoryAsync(_ items: [HistoryItem]) {
        let key = historyKey
        let defaults = historyDefaults
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(items) {
                defaults.set(data, forKey: key)
            }
        }
    }

    private func seasonMilestoneClaimsKey(for userId: String, weekKey: String) -> String {
        let normalized = userId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        let normalizedWeek = weekKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        if normalized.isEmpty || normalized == "-" {
            return "\(seasonMilestoneClaimsBaseKey).guest.\(normalizedWeek)"
        }
        return "\(seasonMilestoneClaimsBaseKey).\(normalized).\(normalizedWeek)"
    }

    private func loadSeasonMilestoneClaims(for userId: String, weekKey: String) -> Set<Int> {
        let key = seasonMilestoneClaimsKey(for: userId, weekKey: weekKey)
        if let numbers = historyDefaults.array(forKey: key) as? [Int] {
            return Set(numbers.filter { $0 > 0 })
        }
        if let strings = historyDefaults.stringArray(forKey: key) {
            let ints = strings.compactMap { Int($0) }.filter { $0 > 0 }
            return Set(ints)
        }
        return []
    }

    private func persistSeasonMilestoneClaims(for userId: String, weekKey: String) {
        let key = seasonMilestoneClaimsKey(for: userId, weekKey: weekKey)
        historyDefaults.set(seasonMilestoneClaimedIDs.sorted(), forKey: key)
    }

    private func publishSeasonMilestoneUpdateIfNeeded(force: Bool = false) {
        let remaining = nextSeasonMilestoneRemainingCount ?? 0
        let digest = "\(seasonWeekKey)|\(seasonTheme.rawValue)|\(seasonLimitedOwnedCount)|\(hasClaimableSeasonMilestoneRewards ? 1 : 0)|\(remaining)"
        if !force, lastPublishedSeasonMilestoneDigest == digest {
            return
        }
        lastPublishedSeasonMilestoneDigest = digest

        NotificationCenter.default.post(
            name: .gachaSeasonMilestoneDidUpdate,
            object: nil,
            userInfo: [
                "weekKey": seasonWeekKey,
                "themeTitle": seasonTheme.title,
                "currentOwnedCount": seasonLimitedOwnedCount,
                "hasClaimableReward": hasClaimableSeasonMilestoneRewards,
                "nextRemainingCount": remaining
            ]
        )
    }

    private func persistSpinMarker(drawID: UUID, count: Int) {
        let marker = SpinMarker(
            drawId: drawID.uuidString,
            count: max(1, count),
            startedAt: Date().timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(marker) {
            historyDefaults.set(data, forKey: spinMarkerKey)
            appendStateAudit("spin-marker saved id=\(marker.drawId) count=\(marker.count)")
        }
    }

    private func clearSpinMarker(reason: String) {
        guard historyDefaults.object(forKey: spinMarkerKey) != nil else { return }
        historyDefaults.removeObject(forKey: spinMarkerKey)
        appendStateAudit("spin-marker cleared reason=\(reason)")
    }

    private func recoverFromPersistedSpinMarkerIfNeeded() {
        guard let data = historyDefaults.data(forKey: spinMarkerKey) else { return }

        let marker = try? JSONDecoder().decode(SpinMarker.self, from: data)
        if let marker {
            let elapsed = max(0.0, Date().timeIntervalSince1970 - marker.startedAt)
            appendStateAudit(
                "spin-marker found on load id=\(marker.drawId) count=\(marker.count) age=\(String(format: "%.1f", elapsed))s"
            )
        } else {
            appendStateAudit("spin-marker found on load but decode failed")
        }

        clearSpinMarker(reason: "load recovery")
        if case .spinning = state {
            transition(to: .idle, reason: "load marker recovery")
        }
        lastMessage = "前回の抽選処理を復旧しました"
        scheduleRefreshProfile()
    }

    private func transition(to newState: State, reason: String) {
        let oldState = state
        state = newState

        appendStateAudit(
            "state \(stateLabel(oldState)) -> \(stateLabel(newState)) reason=\(reason) drawID=\(runningDrawID?.uuidString ?? "-") drawTask=\(drawTask == nil ? "0" : "1") timeout=\(drawTimeoutTask == nil ? "0" : "1") pending=\(pendingDrawSummary == nil ? "0" : "1")"
        )

        let leavingSpinning: Bool = {
            if case .spinning = oldState {
                if case .spinning = newState { return false }
                return true
            }
            return false
        }()
        if leavingSpinning {
            clearSpinMarker(reason: "leave-spinning \(reason)")
            if refreshQueued && refreshTask == nil {
                appendStateAudit("refresh resume after spinning")
                scheduleRefreshProfile()
            }
        }

        switch newState {
        case .spinning:
            spinStateEnteredAt = Date()
            startSpinFailSafe()
        case .idle, .result, .error:
            spinStateEnteredAt = nil
            stopSpinFailSafe()
        }
    }

    private func stateLabel(_ value: State) -> String {
        switch value {
        case .idle:
            return "idle"
        case .spinning:
            return "spinning"
        case .result(let summary):
            return "result(\(summary.drawn.count))"
        case .error(let message):
            let trimmed = message.replacingOccurrences(of: "\n", with: " ")
            let short = trimmed.count > 28 ? String(trimmed.prefix(28)) + "…" : trimmed
            return "error(\(short))"
        }
    }

    private func appendStateAudit(_ text: String) {
        auditSequence += 1
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let line = "#\(auditSequence) \(stamp) \(text)"

        stateAuditTrail.append(line)
        if stateAuditTrail.count > stateAuditLimit {
            stateAuditTrail.removeFirst(stateAuditTrail.count - stateAuditLimit)
        }

        debugLog("[state] \(line)")
    }

    private func startSpinFailSafe() {
        spinFailSafeTask?.cancel()
        appendStateAudit("spin-failsafe start")

        spinFailSafeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
                guard case .spinning = self.state else { return }

                let enteredAt = self.spinStateEnteredAt ?? Date()
                let elapsed = Date().timeIntervalSince(enteredAt)
                let reason = GachaInteractionPolicy.recoveryReason(
                    for: GachaSpinSnapshot(
                        elapsedInSpin: elapsed,
                        hasRunningDrawID: self.runningDrawID != nil,
                        hasDrawTask: self.drawTask != nil,
                        hasTimeoutTask: self.drawTimeoutTask != nil
                    )
                )

                if let reason {
                    switch reason {
                    case .elapsedExceeded:
                        self.forceRecoverFromSpin(reason: "elapsed=\(String(format: "%.1f", elapsed))s")
                    case .noRunningDraw:
                        self.forceRecoverFromSpin(reason: "no-running-draw")
                    case .timeoutTaskMissing:
                        self.forceRecoverFromSpin(reason: "timeout-task-missing")
                    }
                    return
                }
            }
        }
    }

    private func stopSpinFailSafe() {
        guard spinFailSafeTask != nil else { return }
        spinFailSafeTask?.cancel()
        spinFailSafeTask = nil
        appendStateAudit("spin-failsafe stop")
    }

    private func forceRecoverFromSpin(reason: String) {
        guard case .spinning = state else { return }
        appendStateAudit("spin-failsafe trigger reason=\(reason)")

        drawTask?.cancel()
        drawTask = nil
        drawTimeoutTask?.cancel()
        drawTimeoutTask = nil
        runningDrawID = nil

        if let summary = pendingDrawSummary, !summary.drawn.isEmpty {
            transition(to: .result(summary), reason: "failsafe_use_pending_summary")
            return
        }

        let msg = "抽選状態の整合性を回復しました。状態を再同期します"
        transition(to: .error(msg), reason: "failsafe_recover \(reason)")
        lastMessage = msg
        appendSecurityAudit(
            kind: .gachaDrawFailed,
            severity: .error,
            title: "ガチャ整合性回復",
            detail: "failsafe reason=\(reason)"
        )
        scheduleRefreshProfile()
    }

    private func appendSecurityAudit(
        kind: SecurityAuditKind,
        severity: SecurityAuditSeverity = .info,
        title: String,
        detail: String
    ) {
        let actorHint: String? = profileUserId.isEmpty ? nil : String(profileUserId.suffix(8))
        _ = updateMyProfile(
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .gacha,
                kind: kind,
                severity: severity,
                title: title,
                detail: detail,
                actorHint: actorHint
            )
        )
    }

    private func debugLog(_ text: String) {
        #if DEBUG
        logger.debug("\(text, privacy: .public)")
        print("[GachaViewModel] \(text)")
        #endif
    }

    private nonisolated static func exchangeCost(for rarity: CardDecorationRarity) -> Int {
        switch rarity {
        case .common: return 30
        case .rare: return 60
        case .epic: return 120
        case .legendary: return 240
        }
    }
}

extension CardDecorationRarity {
    var rank: Int {
        switch self {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}

private final class GachaIOWorker: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "jp.catloverbot.MyDailyPhrase.gacha.io",
        qos: .userInitiated
    )

    func run<T: Sendable>(_ operation: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: operation())
            }
        }
    }
}
