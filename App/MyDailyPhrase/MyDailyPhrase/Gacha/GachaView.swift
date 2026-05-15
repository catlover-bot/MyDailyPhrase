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
    @State private var presentedResultSummary: GachaDrawSummary? = nil
    @State private var previewItem: CardDecoration? = nil
    @State private var shareSheetItems: [Any] = []
    @State private var isPresentingShareSheet = false
    @State private var isPresentingOddsSheet = false
    @State private var rarityFilter: RarityFilter = .all
    @State private var typeFilter: ItemTypeFilter = .all
    @State private var collectionSort: CollectionSort = .newest

    enum Tab: String {
        case gacha = "ひく"
        case inventory = "所持"
        case exchange = "欠片交換"
        case book = "コレクション"
        case history = "履歴"
        case shop = "購入"
    }

    enum RarityFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case common = "ノーマル"
        case rare = "レア"
        case epic = "エピック"
        case legendary = "レジェンド"

        var id: String { rawValue }

        var rarity: CardDecorationRarity? {
            switch self {
            case .all:
                return nil
            case .common:
                return .common
            case .rare:
                return .rare
            case .epic:
                return .epic
            case .legendary:
                return .legendary
            }
        }
    }

    enum ItemTypeFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case theme = "テーマ"
        case promptPack = "お題"
        case profileTitle = "称号"
        case shareTemplate = "共有"
        case aura = "オーラ"
        case paper = "紙面"
        case reveal = "演出"
        case badge = "バッジ"

        var id: String { rawValue }

        var itemType: DecorationItemType? {
            switch self {
            case .all:
                return nil
            case .theme:
                return .fullTheme
            case .promptPack:
                return .promptPack
            case .profileTitle:
                return .profileTitle
            case .shareTemplate:
                return .shareTemplate
            case .aura:
                return .auraStyle
            case .paper:
                return .journalPaper
            case .reveal:
                return .gachaRevealEffect
            case .badge:
                return .badge
            }
        }
    }

    enum CollectionSort: String, CaseIterable, Identifiable {
        case newest = "新しい順"
        case rarity = "レア順"
        case name = "名前順"

        var id: String { rawValue }
    }

    init(vm: GachaViewModel) {
        self.vm = vm
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            tabSelector

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
                    case .shop where FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled:
                        shopPanel
                    case .shop:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("ガチャ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
            if FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled {
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
            if let mode = overlayCinematicMode {
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
        .fullScreenCover(
            isPresented: Binding(
                get: { presentedResultSummary != nil },
                set: { isPresented in
                    if !isPresented, presentedResultSummary != nil {
                        closeCinematic()
                    }
                }
            )
        ) {
            if let summary = presentedResultSummary {
                GachaResultDetailScreen(
                    summary: summary,
                    pityMax: vm.pityMax,
                    profileDisplayName: vm.profileDisplayName,
                    equippedDecorationId: vm.selectedDecorationId,
                    onEquip: { vm.selectDecoration(id: $0) },
                    onShare: { presentThemeShare(for: $0) },
                    onDrawAgain: canRepeatLastDraw ? { repeatLastDraw() } : nil,
                    onClose: { closeCinematic() }
                )
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
        .animation(.easeInOut(duration: 0.15), value: overlayCinematicMode != nil)
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
        .sheet(isPresented: $isPresentingOddsSheet) {
            NavigationStack {
                GachaOddsDisclosureView(vm: vm)
            }
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
        var tabs: [Tab] = [.gacha, .book, .exchange, .history]
        if FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled {
            tabs.append(.shop)
        }
        return tabs
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableTabs, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            tab = section
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tabSymbol(for: section))
                                .font(.caption.weight(.semibold))
                            Text(section.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(tab == section ? Color.accentColor : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            tab == section
                            ? Color.accentColor.opacity(0.16)
                            : Color(uiColor: .secondarySystemBackground),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    private var equippedItem: CardDecoration? {
        CardDecorationCatalog.byId(vm.selectedDecorationId)
    }

    private var filteredOwnedItems: [CardDecoration] {
        filteredItems(vm.ownedDecorations.map(\.item), ownedOnly: true)
    }

    private var filteredCollectionOwnedItems: [CardDecoration] {
        filteredItems(vm.allDecorations.filter { vm.isOwned($0.id) }, ownedOnly: true)
    }

    private var filteredCollectionLockedItems: [CardDecoration] {
        filteredItems(vm.allDecorations.filter { !vm.isOwned($0.id) }, ownedOnly: false)
    }

    private func filteredItems(_ items: [CardDecoration], ownedOnly: Bool) -> [CardDecoration] {
        items
            .filter { item in
                if let rarity = rarityFilter.rarity, item.rarity != rarity {
                    return false
                }
                if let itemType = typeFilter.itemType, vm.itemMetadata(for: item.id)?.itemType != itemType {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                switch collectionSort {
                case .newest:
                    let lhsDate = vm.ownedRecord(for: lhs.id)?.acquisitionDate ?? (ownedOnly ? .distantPast : .distantFuture)
                    let rhsDate = vm.ownedRecord(for: rhs.id)?.acquisitionDate ?? (ownedOnly ? .distantPast : .distantFuture)
                    if lhsDate != rhsDate { return lhsDate > rhsDate }
                    if lhs.rarity.rank != rhs.rarity.rank { return lhs.rarity.rank > rhs.rarity.rank }
                    return lhs.name < rhs.name
                case .rarity:
                    if lhs.rarity.rank != rhs.rarity.rank { return lhs.rarity.rank > rhs.rarity.rank }
                    return lhs.name < rhs.name
                case .name:
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
    }

    // MARK: - Header

    private var header: some View {
        PageHeroCard(
            eyebrow: "今日のごほうび",
            title: "ガチャで集める",
            subtitle: "無料ガチャやチケットで装飾アイテムを増やして、プロフィールや共有カードの見た目を育てられます。",
            accent: .orange
        ) {
            LazyVGrid(columns: [.init(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                SummaryMetricTile(
                    title: "所持チケット",
                    value: ticketCountText,
                    detail: vm.hasUnlimitedTickets ? "無制限モード" : "単発や10連に使えます",
                    systemImage: "ticket.fill",
                    tint: .blue
                )
                SummaryMetricTile(
                    title: "重複アイテム",
                    value: "\(vm.shards) 欠片",
                    detail: "重複時は欠片に変わります",
                    systemImage: "seal.fill",
                    tint: .orange
                )
                SummaryMetricTile(
                    title: "今日の無料ガチャ",
                    value: "1日1回",
                    detail: "無料券を確認できます",
                    systemImage: "gift.fill",
                    tint: .green
                )
                SummaryMetricTile(
                    title: "レア保証・天井",
                    value: vm.untilPityText,
                    detail: "現在のLEGENDARY率 \(vm.currentLegendaryRateText)",
                    systemImage: "sparkles",
                    tint: .purple
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("現在の進み具合")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(vm.pityText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                pityBar

                Text("10連ではレア以上が1つ確定です。\(vm.untilPityText) なので、必要な枚数だけ使うか無料ガチャを待つかを選べます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        vm.grantDailyTicketIfNeeded()
                    } label: {
                        Label("今日の無料ガチャ", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(vm.isBusy)

                    Button {
                        requestDraw(count: 1) {
                            vm.drawOnce()
                        }
                    } label: {
                        Label("1回ひく", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!vm.canDraw(count: 1))

                    Button {
                        requestDraw(count: 10) {
                            vm.drawTen()
                        }
                    } label: {
                        Label("10連をひく", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!vm.canDraw(count: 10))
                }

                VStack(spacing: 10) {
                    Button {
                        vm.grantDailyTicketIfNeeded()
                    } label: {
                        Label("今日の無料ガチャ", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(vm.isBusy)

                    Button {
                        requestDraw(count: 1) {
                            vm.drawOnce()
                        }
                    } label: {
                        Label("1回ひく", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!vm.canDraw(count: 1))

                    Button {
                        requestDraw(count: 10) {
                            vm.drawTen()
                        }
                    } label: {
                        Label("10連をひく", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!vm.canDraw(count: 10))
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    InfoBadge(title: "プロフィールに反映", systemImage: "person.crop.circle", tint: .blue)
                    InfoBadge(title: "共有カードに反映", systemImage: "square.and.arrow.up", tint: .indigo)
                    InfoBadge(title: "価格情報を更新", systemImage: "arrow.clockwise", tint: .green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoBadge(title: "プロフィールに反映", systemImage: "person.crop.circle", tint: .blue)
                    InfoBadge(title: "共有カードに反映", systemImage: "square.and.arrow.up", tint: .indigo)
                    InfoBadge(title: "価格情報を更新", systemImage: "arrow.clockwise", tint: .green)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            vm.load()
                            await iap.reloadProducts()
                        }
                    } label: {
                        Label("商品情報を更新", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(iap.productLoadState == .loading)

                    Button {
                        isPresentingOddsSheet = true
                    } label: {
                        Label("確率を見る", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(spacing: 10) {
                    Button {
                        Task {
                            vm.load()
                            await iap.reloadProducts()
                        }
                    } label: {
                        Label("商品情報を更新", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(iap.productLoadState == .loading)

                    Button {
                        isPresentingOddsSheet = true
                    } label: {
                        Label("確率を見る", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let msg = vm.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionMsg = vm.actionMessage {
                Text(actionMsg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
    }

    private var ticketCountText: String {
        vm.hasUnlimitedTickets ? "∞" : "\(vm.tickets)"
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
            AppSectionCard(
                title: "ガチャでできること",
                subtitle: "無料ガチャやチケットで装飾アイテムを集めると、プロフィール・共有カード・コミュニティカードの見た目を変えられます。"
            ) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        InfoBadge(title: "無料ガチャあり", systemImage: "gift.fill", tint: .green)
                        InfoBadge(title: "確率を先に確認", systemImage: "info.circle", tint: .indigo)
                        InfoBadge(title: "現金価値なし", systemImage: "shield", tint: .orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "無料ガチャあり", systemImage: "gift.fill", tint: .green)
                        InfoBadge(title: "確率を先に確認", systemImage: "info.circle", tint: .indigo)
                        InfoBadge(title: "現金価値なし", systemImage: "shield", tint: .orange)
                    }
                }
            }

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

            AppSectionCard(
                title: "引いたあとの使い道",
                subtitle: "結果画面からすぐ装備したり、あとでコレクションから使い分けたりできます。"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("結果画面で見た目をプレビュー", systemImage: "sparkles.rectangle.stack")
                            .font(.subheadline.weight(.semibold))
                        Label("その場で装備してプロフィールや共有カードに反映", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                        Label("重複アイテムは欠片に変わり、未所持アイテム交換に使える", systemImage: "seal.fill")
                            .font(.subheadline.weight(.semibold))
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            Button {
                                tab = .book
                            } label: {
                                Label("コレクションを見る", systemImage: "square.grid.2x2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                isPresentingOddsSheet = true
                            } label: {
                                Label("確率を見る", systemImage: "info.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(spacing: 10) {
                            Button {
                                tab = .book
                            } label: {
                                Label("コレクションを見る", systemImage: "square.grid.2x2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                isPresentingOddsSheet = true
                            } label: {
                                Label("確率を見る", systemImage: "info.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            AppSectionCard(
                title: "コレクション",
                subtitle: "手に入れたアイテムはあとからプレビュー・装備・共有できます。"
            ) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        InfoBadge(title: "装備中を確認", systemImage: "person.crop.circle.badge.checkmark", tint: .blue)
                        InfoBadge(title: "最近の獲得を見返す", systemImage: "clock.arrow.circlepath", tint: .purple)
                        InfoBadge(title: "使い道を確認", systemImage: "rectangle.on.rectangle", tint: .green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoBadge(title: "装備中を確認", systemImage: "person.crop.circle.badge.checkmark", tint: .blue)
                        InfoBadge(title: "最近の獲得を見返す", systemImage: "clock.arrow.circlepath", tint: .purple)
                        InfoBadge(title: "使い道を確認", systemImage: "rectangle.on.rectangle", tint: .green)
                    }
                }

                Button {
                    tab = .book
                } label: {
                    Label("コレクションを見る", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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

                    Text((FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled)
                         ? (iap.isCreatorPassActive
                            ? "Creator Passで毎日無料券ボーナス。確率と重複時の欠片変換を確認してから、必要な分だけ回せます。"
                            : "チケットパックと Creator Pass は安全に読み込めた商品だけ表示されます。参加は無料のままです。")
                         : "毎日の無料券と交換所を使いながら、少しずつコレクションを増やせます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled {
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

                            Button {
                                isPresentingOddsSheet = true
                            } label: {
                                Label("確率を見る", systemImage: "info.circle")
                                    .compactActionLabel()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
                HStack {
                    Text("排出確率と安全性")
                    Spacer()
                    Button {
                        isPresentingOddsSheet = true
                    } label: {
                        Label("詳細", systemImage: "info.circle")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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

                ForEach(MonetizationDisclosure.ownershipLines, id: \.self) { line in
                    Text(line)
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

            if let equippedItem {
                VStack(alignment: .leading, spacing: 8) {
                    Text("装備中")
                        .font(.subheadline.weight(.semibold))
                    GachaCollectionTile(
                        item: equippedItem,
                        ownedCount: vm.ownedCount(for: equippedItem.id),
                        isOwned: true,
                        isEquipped: true
                    ) {
                        previewItem = equippedItem
                    }
                }
            }

            collectionControls

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
                ForEach(filteredOwnedItems, id: \.id) { item in
                    GachaCollectionTile(
                        item: item,
                        ownedCount: vm.ownedCount(for: item.id),
                        isOwned: true,
                        isEquipped: vm.isSelected(item.id)
                    ) {
                        previewItem = item
                    }
                }
            }

            if filteredOwnedItems.isEmpty {
                Text("この条件に合う所持アイテムはまだありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            collectionControls

            if let equippedItem {
                VStack(alignment: .leading, spacing: 8) {
                    Text("装備中")
                        .font(.subheadline.weight(.semibold))
                    GachaCollectionTile(
                        item: equippedItem,
                        ownedCount: vm.ownedCount(for: equippedItem.id),
                        isOwned: true,
                        isEquipped: true
                    ) {
                        previewItem = equippedItem
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("所持")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filteredCollectionOwnedItems, id: \.id) { d in
                        GachaCollectionTile(
                            item: d,
                            ownedCount: vm.ownedCount(for: d.id),
                            isOwned: true,
                            isEquipped: vm.isSelected(d.id)
                        ) {
                            previewItem = d
                        }
                    }
                }
                if filteredCollectionOwnedItems.isEmpty {
                    Text("この条件に合う所持アイテムはまだありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("未所持")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filteredCollectionLockedItems, id: \.id) { d in
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
                if filteredCollectionLockedItems.isEmpty {
                    Text("この条件では未所持アイテムがありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("※「限定」アイテムは通常ガチャ対象外です")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var collectionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    rarityFilterPicker
                    typeFilterPicker
                }

                VStack(spacing: 10) {
                    rarityFilterPicker
                    typeFilterPicker
                }
            }

            Picker("並び順", selection: $collectionSort) {
                ForEach(CollectionSort.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var rarityFilterPicker: some View {
        Picker("レア度", selection: $rarityFilter) {
            ForEach(RarityFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.menu)
    }

    private var typeFilterPicker: some View {
        Picker("種類", selection: $typeFilter) {
            ForEach(ItemTypeFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.menu)
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
            AppSectionCard(
                title: "チケット購入とCreator Pass",
                subtitle: "無料ガチャや手持ちチケットを先に楽しめます。購入は必要なときだけ、Appleの安全な決済で行えます。"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(MonetizationDisclosure.purchaseSafetyLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isPresentingOddsSheet = true
                    } label: {
                        Label("提供割合と重複時の扱いを確認する", systemImage: "info.circle")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !iap.hasLoadedAnyProducts {
                AppSectionCard(
                    title: "価格情報を確認中です",
                    subtitle: "App Storeの商品情報の反映待ちです。しばらくしてから再読み込みしてください。"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("購入できるのは、価格が確認できた商品だけです。", systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("表示が準備中でも、チケットの使い道や Creator Pass の内容は先に確認できます。価格が確認できるまでは、安全のため購入操作を止めています。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        storeRecoveryActions
                    }
                }
            }

            AppSectionCard(
                title: iap.productStatusTitle,
                subtitle: iap.productStatusMessage
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    statusBadgeRow

                    storeRecoveryActions

                    if let msg = iap.lastMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            AppSectionCard(
                title: "Creator Pass",
                subtitle: "コミュニティ作成とお題カスタマイズを解放します。参加者は無料のままです。"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            PremiumBadge(title: iap.isCreatorPassActive ? "Creator Pass 有効" : "Creator Pass")
                            InfoBadge(title: "参加者は無料", systemImage: "person.badge.plus", tint: .green)
                            InfoBadge(title: "毎日の無料券ボーナス", systemImage: "gift.fill", tint: .orange)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PremiumBadge(title: iap.isCreatorPassActive ? "Creator Pass 有効" : "Creator Pass")
                            InfoBadge(title: "参加者は無料", systemImage: "person.badge.plus", tint: .green)
                            InfoBadge(title: "毎日の無料券ボーナス", systemImage: "gift.fill", tint: .orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(iap.creatorPassBenefitLines, id: \.self) { benefit in
                            Label(benefit, systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if !FeatureFlags.creatorPassEnabled {
                        Text("参加は無料です。コミュニティ作成とお題カスタマイズは、Creator Pass が有効になったときに解放されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !iap.creatorPassProducts.isEmpty {
                        ForEach(iap.creatorPassProducts, id: \.id) { product in
                            Button {
                                Task { await iap.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(creatorPassCaption(for: product))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!iap.isCreatorPassShopAvailable)
                        }
                    } else {
                        disabledCreatorPassCard
                    }
                }
            }

            AppSectionCard(
                title: "チケット購入",
                subtitle: "有料チケットは任意です。無料ガチャや交換所でも少しずつコレクションを増やせます。"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(iap.ticketValuePitchLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(ticketPackStates) { state in
                        ticketPackCard(state)
                    }

                    Text("装飾アイテム専用 / 現金価値なし / 譲渡・売買・換金不可 / 確率を確認できます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            #if DEBUG
            DisclosureGroup("StoreKit 状態（開発用）") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(iap.debugStatusLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)
            }
            .font(.caption2)
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            #endif
        }
    }

    private var ticketPackStates: [TicketPackPurchaseCardState] {
        let displayPrices = Dictionary(uniqueKeysWithValues: iap.ticketProducts.map { ($0.id, $0.displayPrice) })
        return MonetizationShopSupport.ticketPackStates(
            availability: iap.productLoadState,
            loadedProductIDs: Set(iap.loadedProductIDs),
            displayPrices: displayPrices,
            bestValueProductID: iap.bestValueTicketProductID
        )
    }

    private var statusBadgeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                InfoBadge(title: "装飾アイテム専用", systemImage: "paintpalette", tint: .blue)
                InfoBadge(title: "外部決済リンクなし", systemImage: "checkmark.shield", tint: .green)
                InfoBadge(title: "購入前に確率確認", systemImage: "info.circle", tint: .indigo)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoBadge(title: "装飾アイテム専用", systemImage: "paintpalette", tint: .blue)
                InfoBadge(title: "外部決済リンクなし", systemImage: "checkmark.shield", tint: .green)
                InfoBadge(title: "購入前に確率確認", systemImage: "info.circle", tint: .indigo)
            }
        }
    }

    private var storeRecoveryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button {
                    Task { await iap.reloadProducts() }
                } label: {
                    Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await iap.sync() }
                } label: {
                    Label("購入情報を復元", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await iap.reloadProducts() }
                } label: {
                    Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await iap.sync() }
                } label: {
                    Label("購入情報を復元", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var disabledCreatorPassCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator Pass")
                        .font(.subheadline.weight(.semibold))
                    Text("コミュニティ作成とお題カスタマイズを解放")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("参加者は無料のままです")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PremiumBadge(title: "価格情報を確認中")
            }

            Text("現在、価格情報を準備中です")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("App Storeの商品情報の反映待ちです。価格が確認できるまでは、安全のため購入ボタンを表示していません。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            storeRecoveryActions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.10),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.14), lineWidth: 1)
        )
    }

    private func ticketPackCard(_ state: TicketPackPurchaseCardState) -> some View {
        let loadedProduct = iap.ticketProducts.first(where: { $0.id == state.productID })
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(state.title)
                            .font(.subheadline.weight(.semibold))
                        if state.isRecommended {
                            Text("まとめて楽しみたい方に")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    Text(state.statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("チケットはガチャ演出やテーマ収集に使えます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let loadedProduct, let unitPriceText = iap.ticketUnitPriceText(for: loadedProduct) {
                        Text(unitPriceText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(state.displayPrice ?? "準備中")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(state.isEnabled ? "購入できます" : "価格を確認中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if state.isEnabled, let loadedProduct {
                Button {
                    Task { await iap.purchase(loadedProduct) }
                } label: {
                    Label("購入する", systemImage: "cart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(.secondary)
                    Text("App Storeの商品情報の反映待ちです。価格が確認できるまで、このパックは購入できません。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private var overlayCinematicMode: GachaCinematicOverlay.Mode? {
        if case .spinning = vm.state {
            if hidesSpinningCinematic { return nil }
            return .spinning(count: lastDrawCount, bannerTitle: vm.currentBanner.title)
        }
        if let revealSummary {
            return .revealing(summary: revealSummary, index: revealIndex)
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
        presentedResultSummary = nil
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
                presentedResultSummary = summary
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
            if let summary = vm.currentResult {
                presentedResultSummary = summary
            }
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
        presentedResultSummary = nil
        vm.closeResult()
    }

    private var canRepeatLastDraw: Bool {
        vm.canDraw(count: lastDrawCount)
    }

    private func repeatLastDraw() {
        presentedResultSummary = nil
        revealTask?.cancel()
        revealSummary = nil
        vm.closeResult()
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
            revealPhrase: GachaThemePresentation.revealPhrase(for: item),
            statusLine: vm.isSelected(item.id) ? "現在プロフィールに反映中" : "プロフィールや共有カードに反映できます",
            decorationId: item.id,
            profileTitle: GachaThemePresentation.profileTitle(for: item)
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

    private func creatorPassCaption(for product: Product) -> String {
        switch MonetizationProducts.creatorPassKind(for: product.id) {
        case .lifetime:
            return "買い切り / コミュニティ作成を解放"
        case .monthly:
            return "月額 / コミュニティ作成を解放"
        case .yearly:
            return "年額 / コミュニティ作成を解放"
        case nil:
            return "コミュニティ作成を解放"
        }
    }

    private func tabSymbol(for tab: Tab) -> String {
        switch tab {
        case .gacha:
            return "sparkles"
        case .inventory:
            return "shippingbox.fill"
        case .exchange:
            return "seal.fill"
        case .book:
            return "square.grid.2x2.fill"
        case .history:
            return "clock.arrow.circlepath"
        case .shop:
            return "cart.fill"
        }
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
                presentedResultSummary = summary
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
            presentedResultSummary = nil
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
                        presentedResultSummary = summary
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

private struct GachaOddsDisclosureView: View {
    @ObservedObject var vm: GachaViewModel
    @Environment(\.dismiss) private var dismiss

    private let duplicateRows: [(String, Int)] = [
        ("ノーマル重複", GachaOddsPolicy.duplicateShardReward(for: .common)),
        ("レア重複", GachaOddsPolicy.duplicateShardReward(for: .rare)),
        ("エピック重複", GachaOddsPolicy.duplicateShardReward(for: .epic)),
        ("レジェンド重複", GachaOddsPolicy.duplicateShardReward(for: .legendary))
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通常時の提供割合")
                        .font(.headline)

                    ForEach(vm.weightTable, id: \.label) { row in
                        HStack {
                            Text(row.label)
                            Spacer()
                            Text(row.value)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    Text("最終更新: \(MonetizationProducts.oddsDisclosureVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("アイテム別の目安")
                        .font(.headline)

                    ForEach(vm.itemWeightTable) { row in
                        HStack(spacing: 8) {
                            Text(row.name)
                                .font(.subheadline.weight(.semibold))
                            Text(row.rarity)
                                .font(.caption)
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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("重複時の扱い")
                        .font(.headline)

                    ForEach(duplicateRows, id: \.0) { row in
                        HStack {
                            Text(row.0)
                            Spacer()
                            Text("欠片 +\(row.1)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    Text("欠片はローカルな装飾交換にのみ使えます。現金価値はなく、売買や譲渡はできません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("注意事項")
                        .font(.headline)

                    ForEach(MonetizationDisclosure.ownershipLines + vm.oddsNotes, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding()
        }
        .navigationTitle("提供割合")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }
}
