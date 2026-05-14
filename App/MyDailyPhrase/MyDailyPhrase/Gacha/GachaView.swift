import SwiftUI
import StoreKit
import Domain
import UIKit
import Presentation

struct GachaView: View {
    @ObservedObject var vm: GachaViewModel
    @EnvironmentObject private var iap: IAPStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: Tab = .gacha
    @State private var revealSummary: GachaDrawSummary? = nil
    @State private var revealIndex: Int = 0
    @State private var lastDrawCount: Int = 1
    @State private var revealTask: Task<Void, Never>? = nil
    @State private var spinWatchdogTask: Task<Void, Never>? = nil
    @State private var spinStartedAt: Date? = nil
    @State private var skipToResultAfterSpin: Bool = false
    @State private var hidesSpinningCinematic: Bool = false
    @State private var showsErrorAlert = false
    @State private var showsDiagnostics = false
    @State private var drawTapLockedUntil: Date? = nil
    @State private var previewItem: CardDecoration? = nil
    @State private var shareSheetItems: [Any] = []
    @State private var isPresentingShareSheet = false

    enum Tab: String {
        case gacha = "ガチャ"
        case inventory = "所持"
        case exchange = "交換"
        case book = "コレクション"
        case history = "履歴"
        case shop = "購入"
    }

    init(vm: GachaViewModel) {
        self.vm = vm
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            Picker("", selection: $tab) {
                ForEach(availableTabs, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 12) {
                    switch tab {
                    case .gacha:
                        gachaPanel
                    case .inventory:
                        inventoryPanel
                    case .exchange:
                        exchangePanel
                    case .book:
                        bookPanel
                    case .history:
                        historyPanel
                    case .shop where FeatureFlags.paidGachaEnabled:
                        shopPanel
                    case .shop:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("ガチャ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
            if FeatureFlags.paidGachaEnabled {
                await iap.configure()
            }
        }
        .onAppear {
            handleStateChange(vm.state)
        }
        .onChange(of: vm.state) { _, st in
            handleStateChange(st)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if case .spinning = vm.state {
                startSpinWatchdog()
                if let start = spinStartedAt,
                   Date().timeIntervalSince(start) > 10.0 {
                    vm.recoverFromStuckSpinIfNeeded()
                }
            }
        }
        .overlay {
            if let mode = cinematicMode {
                GachaCinematicOverlay(
                    mode: mode,
                    pityMax: vm.pityMax,
                    profileDisplayName: vm.profileDisplayName,
                    equippedDecorationId: vm.selectedDecorationId,
                    onSkip: { skipReveal() },
                    onEquip: { vm.selectDecoration(id: $0) },
                    onShare: { presentThemeShare(for: $0) },
                    onDrawAgain: canRepeatLastDraw ? { repeatLastDraw() } : nil,
                    onClose: { closeCinematic() }
                )
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = statusBannerMessage {
                actionBanner(msg)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: cinematicMode != nil)
        .animation(.easeInOut(duration: 0.15), value: statusBannerMessage != nil)
        .alert("ガチャエラー", isPresented: $showsErrorAlert) {
            Button("再同期") {
                vm.recoverNow()
            }
            Button("閉じる", role: .cancel) {
                vm.clearError()
            }
        } message: {
            Text(vm.currentErrorText ?? "不明なエラーが発生しました")
        }
        .sheet(item: $previewItem) { item in
            GachaThemePreviewSheet(
                item: item,
                ownedCount: vm.ownedCount(for: item.id),
                isOwned: vm.isOwned(item.id),
                isEquipped: vm.isSelected(item.id),
                profileDisplayName: vm.profileDisplayName,
                onEquip: {
                    vm.selectDecoration(id: item.id)
                },
                onShare: {
                    presentThemeShare(for: item)
                }
            )
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ShareSheet(activityItems: shareSheetItems)
        }
        .onDisappear {
            revealTask?.cancel()
            spinWatchdogTask?.cancel()
        }
    }

    private var availableTabs: [Tab] {
        var tabs: [Tab] = [.gacha, .inventory, .exchange, .book, .history]
        if FeatureFlags.paidGachaEnabled {
            tabs.append(.shop)
        }
        return tabs
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("チケット")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(ticketCountText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("\(vm.profileDisplayName) / ID: \(vm.profileUserId.suffix(6))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("欠片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(vm.shards)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }

                Button {
                    vm.grantDailyTicketIfNeeded()
                } label: {
                    VStack(spacing: 4) {
                        Text("デイリー")
                            .font(.caption2)
                        Text("無料券")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(vm.isBusy)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                pityBar
                HStack(spacing: 8) {
                    Text(vm.untilPityText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Label(vm.stateSummary.label, systemImage: stateIconName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(vm.currentErrorText == nil ? Color.secondary : Color.red)
                }
                .padding(.top, 2)

                HStack {
                    Text(vm.stateSummary.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button("再同期") {
                        vm.recoverNow()
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                }
                if let msg = vm.lastMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let actionMsg = vm.actionMessage {
                    Text(actionMsg)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private var ticketCountText: String {
        vm.hasUnlimitedTickets ? "∞" : "\(vm.tickets)"
    }

    private var stateIconName: String {
        switch vm.state {
        case .idle: return "checkmark.circle"
        case .spinning: return "hourglass"
        case .result: return "gift"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var pityBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.pityText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                let prog = min(1.0, Double(vm.pity) / Double(vm.pityMax))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999).fill(Color.black.opacity(0.08))
                    RoundedRectangle(cornerRadius: 999).fill(Color.black.opacity(0.16))
                        .frame(width: w * prog)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Panels

    private var gachaPanel: some View {
        VStack(spacing: 12) {
            bannerCard

            if FeatureFlags.themePreviewEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label("テーマはプロフィール・共有カード・プレビューで見た目が変わります", systemImage: "sparkles.rectangle.stack")
                        .font(.subheadline.weight(.semibold))
                    Text("抽選後は、その場でプレビュー確認・装備・共有までできます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if FeatureFlags.communityEnabled && vm.seasonLimitedTotalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(vm.seasonLimitedCollectionProgressText, systemImage: "calendar.badge.clock")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(vm.seasonLimitedCollectionRate * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: vm.seasonLimitedCollectionRate, total: 1.0)

                    Text("限定デコは通常ガチャ対象外です。シーズン施策として順次開放予定です。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(vm.seasonThemeTitleText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("テーマ別ピックアップ: \(vm.seasonThemePickupPreviewText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(vm.seasonRewardPreviewRows, id: \.self) { row in
                        Text(row)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("シーズン収集ミッション", systemImage: "trophy")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Text(vm.seasonMilestoneSummaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(vm.seasonMilestoneRows) { row in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.reward.title)
                                    .font(.caption.weight(.semibold))
                                Text("限定デコ \(row.progressText) / \(row.rewardText)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(milestoneStatusText(row))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(milestoneStatusColor(row))
                        }
                        .padding(.vertical, 2)
                    }

                    if vm.hasClaimableSeasonMilestoneRewards {
                        Button {
                            vm.claimSeasonMilestoneRewards()
                        } label: {
                            Label("シーズン報酬を受け取る", systemImage: "gift.fill")
                                .compactActionLabel()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("gacha.seasonMilestone.claim")
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 10) {
                Button {
                    requestDraw(count: 1) {
                        vm.drawOnce()
                    }
                } label: {
                    Text("単発 (1)")
                        .compactActionLabel()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canDraw(count: 1))
                .accessibilityIdentifier("gacha.draw.once")

                Button {
                    requestDraw(count: 10) {
                        vm.drawTen()
                    }
                } label: {
                    Text("10連 (10)")
                        .compactActionLabel()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(!vm.canDraw(count: 10))
                .accessibilityIdentifier("gacha.draw.ten")
            }

            if vm.tickets < 10 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("あと少しで10連", systemImage: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("所持 \(vm.tickets)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(FeatureFlags.paidGachaEnabled
                         ? (iap.isCreatorPassActive
                            ? "Creator Passで毎日無料券ボーナス。チケットパック併用で回転率を上げられます。"
                            : "チケットパック + Creator Pass で、毎日の無料券ボーナスと長期運用の回転率を両立できます。")
                         : "毎日の無料券と交換所を使いながら、少しずつコレクションを増やせます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if FeatureFlags.paidGachaEnabled {
                        HStack(spacing: 8) {
                            Button {
                                tab = .shop
                            } label: {
                                Label("ショップへ", systemImage: "cart")
                                    .compactActionLabel()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            if let bestId = iap.bestValueTicketProductID,
                               let best = iap.ticketProducts.first(where: { $0.id == bestId }) {
                                Button {
                                    Task { await iap.purchase(best) }
                                } label: {
                                    Label("おすすめ \(best.displayPrice)", systemImage: "sparkles")
                                        .compactActionLabel()
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } else {
                        Button {
                            vm.grantDailyTicketIfNeeded()
                        } label: {
                            Label("無料券を確認する", systemImage: "calendar.badge.plus")
                                .compactActionLabel()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("提供割合（通常時）")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(vm.weightTable, id: \.label) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text(row.value)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                }

                DisclosureGroup("アイテム別の提供割合（目安）") {
                    VStack(spacing: 8) {
                        ForEach(vm.itemWeightTable) { row in
                            HStack(spacing: 8) {
                                Text(row.name)
                                    .font(.caption2.weight(.semibold))
                                Text(row.rarity)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if row.isFeatured {
                                    Text("PICKUP")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text(row.value)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.caption2)

                ForEach(vm.oddsNotes, id: \.self) { note in
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            #if DEBUG
            diagnosticsPanel
            #endif
        }
    }

    private var inventoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("所持アイテム")
                        .font(.headline)
                    Text("タップすると見た目を確認して、あとから装備できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if FeatureFlags.nativeSharingEnabled,
                   let equippedItem = CardDecorationCatalog.byId(vm.selectedDecorationId) {
                    Button {
                        presentThemeShare(for: equippedItem)
                    } label: {
                        Label("装備中を共有", systemImage: "square.and.arrow.up")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if FeatureFlags.communityEnabled && vm.seasonLimitedTotalCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.seasonLimitedCollectionProgressText)
                        .font(.caption.weight(.semibold))
                    ProgressView(value: vm.seasonLimitedCollectionRate, total: 1.0)
                    if vm.seasonLimitedOwnedDecorations.isEmpty {
                        Text("まだ限定デコはありません。今後のシーズン施策で順次追加予定です。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(vm.ownedDecorations, id: \.item.id) { x in
                    GachaCollectionTile(
                        item: x.item,
                        ownedCount: x.count,
                        isOwned: true,
                        isEquipped: vm.isSelected(x.item.id)
                    ) {
                        previewItem = x.item
                    }
                }
            }
        }
    }

    private var exchangePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("交換所（欠片 → 装飾）")
                .font(.headline)

            Text("未所持の装飾を欠片で交換できます。重複を狙わない救済として機能します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(vm.exchangeCandidates, id: \.id) { d in
                    let cost = vm.exchangeCost(for: d)
                    let affordable = vm.shards >= cost

                    itemCard(
                        title: d.name,
                        subtitle: GachaThemePresentation.rarityLabel(for: d.rarity),
                        trailing: "欠片 \(cost)",
                        isSelected: vm.isSelected(d.id),
                        isLocked: !affordable || vm.isActionRunning,
                        badge: vm.isSeasonLimited(d.id) ? "限定" : nil
                    ) {
                        vm.exchange(decorationId: d.id)
                    }
                }
            }
        }
    }

    private var bookPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("コレクション")
                .font(.headline)

            Text("所持・未所持・装備中をまとめて確認できます。未所持アイテムもプレビュー可能です。")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(vm.allDecorations, id: \.id) { d in
                    GachaCollectionTile(
                        item: d,
                        ownedCount: vm.ownedCount(for: d.id),
                        isOwned: vm.isOwned(d.id),
                        isEquipped: vm.isSelected(d.id)
                    ) {
                        previewItem = d
                    }
                }
            }

            Text("※「限定」アイテムは通常ガチャ対象外です")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ガチャ履歴（最大 \(vm.historyLimit) 件）")
                .font(.headline)

            if vm.history.isEmpty {
                Text("履歴はまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.history) { h in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(h.dateText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("欠片+\(h.shardsGained) / 天井 \(h.pityAfter)/\(vm.pityMax)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(h.itemsText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button("履歴をクリア") {
                        vm.clearHistory()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var shopPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ショップ")
                .font(.headline)

            switch iap.state {
            case .idle, .loading:
                HStack { ProgressView(); Text("読み込み中…") }
                    .foregroundStyle(.secondary)

            case .failed(let msg):
                Text(msg).foregroundStyle(.secondary)

            case .ready:
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Creator Pass")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(iap.isCreatorPassActive ? "有効" : "未加入")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(iap.isCreatorPassActive ? .green : .secondary)
                        }
                        Text(iap.creatorPassStatusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(iap.creatorPassBenefitLines, id: \.self) { benefit in
                            Label(benefit, systemImage: "checkmark.seal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if iap.creatorPassProducts.isEmpty {
                            Text("Creator Pass商品がありません")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(iap.creatorPassProducts, id: \.id) { p in
                                Button {
                                    Task { await iap.purchase(p) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.displayName).fontWeight(.semibold)
                                            Text(p.id).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(p.displayPrice).fontWeight(.semibold)
                                    }
                                    .padding(14)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("チケット購入")
                            .font(.subheadline.weight(.semibold))
                        ForEach(iap.ticketValuePitchLines, id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if iap.ticketProducts.isEmpty {
                            Text("チケット商品がありません")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(iap.ticketProducts, id: \.id) { p in
                                let amount = iap.ticketAmount(for: p)
                                let isBestValue = iap.isBestValueTicketProduct(p)
                                Button {
                                    Task { await iap.purchase(p) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(p.displayName).fontWeight(.semibold)
                                                if isBestValue {
                                                    Text("BEST VALUE")
                                                        .font(.caption2.weight(.bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.thinMaterial)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            Text("チケット \(amount)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            if let unitPriceText = iap.ticketUnitPriceText(for: p) {
                                                Text(unitPriceText)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(p.displayPrice).fontWeight(.semibold)
                                    }
                                    .padding(14)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if let msg = iap.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            Button("App Storeと同期") {
                Task { await iap.sync() }
            }
            .padding(.top, 8)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - UI Parts

    private var bannerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.currentBanner.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(vm.currentBanner.subtitle)
                .font(.title3)
                .fontWeight(.bold)
            Text(vm.currentBanner.note)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(vm.currentBanner.featuredIds, id: \.self) { id in
                    Text(featuredDisplayName(id))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func itemCard(
        title: String,
        subtitle: String,
        trailing: String,
        isSelected: Bool,
        isLocked: Bool,
        badge: String? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        let badgeTint: Color = (badge == "限定") ? .orange : .secondary

        return Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if let badge {
                                Text(badge)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(badgeTint.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                    if isSelected { Image(systemName: "checkmark.circle.fill") }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var cinematicMode: GachaCinematicOverlay.Mode? {
        if case .spinning = vm.state {
            if hidesSpinningCinematic { return nil }
            return .spinning(count: lastDrawCount, bannerTitle: vm.currentBanner.title)
        }
        if let revealSummary {
            return .revealing(summary: revealSummary, index: revealIndex)
        }
        if case .result(let summary) = vm.state {
            return .result(summary: summary)
        }
        return nil
    }

    private var statusBannerMessage: String? {
        if hidesSpinningCinematic, case .spinning = vm.state {
            return "結果を取得中…"
        }
        return vm.actionMessage
    }

    private func startReveal(_ summary: GachaDrawSummary) {
        revealTask?.cancel()
        revealSummary = summary
        revealIndex = 0

        revealTask = Task { @MainActor in
            let n = max(1, summary.drawn.count)
            for i in 0..<n {
                if Task.isCancelled { return }
                revealSummary = summary
                revealIndex = i
                let drawn = summary.drawn
                let isLegendary = drawn.indices.contains(i) && drawn[i].rarity == .legendary
                let wait: UInt64
                if reduceMotion {
                    wait = isLegendary ? 180_000_000 : 120_000_000
                } else {
                    wait = isLegendary ? 420_000_000 : 260_000_000
                }
                try? await Task.sleep(nanoseconds: UInt64(wait))
            }
            if !Task.isCancelled {
                revealSummary = nil
            }
        }
    }

    private func skipReveal() {
        switch GachaInteractionPolicy.skipDecision(
            isRevealActive: revealSummary != nil,
            state: gachaLifecycleState
        ) {
        case .closeReveal:
            revealTask?.cancel()
            revealSummary = nil
        case .hideSpinAndAwaitResult:
            // 抽選自体は継続し、演出だけスキップする
            skipToResultAfterSpin = true
            hidesSpinningCinematic = true
            revealSummary = nil
            startSpinWatchdog()
        case .ignored:
            break
        }
    }

    private func closeCinematic() {
        if case .spinning = vm.state {
            skipReveal()
            return
        }

        skipToResultAfterSpin = false
        hidesSpinningCinematic = false
        revealTask?.cancel()
        spinWatchdogTask?.cancel()
        spinStartedAt = nil
        revealSummary = nil
        vm.closeResult()
    }

    private var canRepeatLastDraw: Bool {
        vm.canDraw(count: lastDrawCount)
    }

    private func repeatLastDraw() {
        requestDraw(count: lastDrawCount) {
            if lastDrawCount >= 10 {
                vm.drawTen()
            } else {
                vm.drawOnce()
            }
        }
    }

    private func presentThemeShare(for item: CardDecoration) {
        guard FeatureFlags.nativeSharingEnabled else { return }

        let model = GachaShareCardModel(
            appName: "ひとこと日記",
            itemName: item.name,
            rarityLabel: GachaThemePresentation.rarityLabel(for: item.rarity),
            flavorText: GachaThemePresentation.flavorText(for: item),
            revealPhrase: GachaThemePresentation.revealPhrase(for: item.rarity),
            statusLine: vm.isSelected(item.id) ? "現在プロフィールに反映中" : "プロフィールや共有カードに反映できます",
            decorationId: item.id
        )

        let text = GachaThemePresentation.shareText(
            appDisplayName: "ひとこと日記",
            item: item,
            isEquipped: vm.isSelected(item.id)
        )
        let image = GachaShareCardRenderer.render(model: model)?.image
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: nil)
        isPresentingShareSheet = true
    }

    private func featuredDisplayName(_ id: String) -> String {
        CardDecorationCatalog.byId(id)?.name ?? id
    }

    private var diagnosticsPanel: some View {
        DisclosureGroup("状態監査（開発用）", isExpanded: $showsDiagnostics) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(vm.diagnosticsSummaryLines, id: \.self) { line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("ログをコピー") {
                        UIPasteboard.general.string = vm.stateAuditExportText
                        vm.lastMessage = "監査ログをコピーしました"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("ログをクリア") {
                        vm.clearStateAudits()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button("再同期") {
                        vm.recoverNow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(vm.latestStateAudits.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding(.top, 8)
        }
        .font(.caption2)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func milestoneStatusText(_ row: GachaViewModel.SeasonMilestoneRow) -> String {
        if row.isClaimed { return "受取済み" }
        if row.isClaimable { return "受取可能" }
        return "進行中"
    }

    private func milestoneStatusColor(_ row: GachaViewModel.SeasonMilestoneRow) -> Color {
        if row.isClaimed { return .secondary }
        if row.isClaimable { return .green }
        return .secondary
    }

    private func handleStateChange(_ st: GachaViewModel.State) {
        switch st {
        case .spinning:
            spinStartedAt = Date()
            skipToResultAfterSpin = false
            hidesSpinningCinematic = false
            revealTask?.cancel()
            revealSummary = nil
            startSpinWatchdog()
        case .result(let summary):
            spinWatchdogTask?.cancel()
            spinStartedAt = nil
            hidesSpinningCinematic = false
            drawTapLockedUntil = nil
            if skipToResultAfterSpin {
                skipToResultAfterSpin = false
                revealSummary = nil
            } else {
                startReveal(summary)
            }
        case .idle, .error:
            spinWatchdogTask?.cancel()
            spinStartedAt = nil
            skipToResultAfterSpin = false
            hidesSpinningCinematic = false
            drawTapLockedUntil = nil
            revealTask?.cancel()
            revealSummary = nil
            if case .error = st {
                showsErrorAlert = true
            }
        }
    }

    private func startSpinWatchdog() {
        spinWatchdogTask?.cancel()
        spinWatchdogTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }

                switch vm.state {
                case .result(let summary):
                    if skipToResultAfterSpin {
                        skipToResultAfterSpin = false
                        revealSummary = nil
                    } else {
                        startReveal(summary)
                    }
                    return
                case .idle, .error:
                    revealSummary = nil
                    return
                case .spinning:
                    if let start = spinStartedAt,
                       Date().timeIntervalSince(start) > 10.0 {
                        vm.recoverFromStuckSpinIfNeeded()
                        return
                    }
                }
            }
        }
    }

    private var gachaLifecycleState: GachaViewLifecycleState {
        switch vm.state {
        case .idle:
            return .idle
        case .spinning:
            return .spinning
        case .result:
            return .result
        case .error:
            return .error
        }
    }

    private func requestDraw(count: Int, action: () -> Void) {
        let decision = GachaInteractionPolicy.drawTapDecision(
            isBusy: vm.isBusy,
            now: Date(),
            lockedUntil: drawTapLockedUntil
        )
        drawTapLockedUntil = decision.nextLockedUntil
        guard decision.accepted else { return }

        lastDrawCount = count
        action()
    }

    private func actionBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                Button("再同期") {
                    vm.recoverNow()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private extension View {
    func compactActionLabel() -> some View {
        labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}
