import SwiftUI
import StoreKit
import Domain

struct GachaView: View {
    @ObservedObject var vm: GachaViewModel
    @EnvironmentObject private var iap: IAPStore

    @State private var tab: Tab = .gacha

    enum Tab: String, CaseIterable {
        case gacha = "ガチャ"
        case inventory = "所持"
        case exchange = "交換"
        case book = "図鑑"
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
                ForEach(Tab.allCases, id: \.self) { t in
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
                    case .shop:
                        shopPanel
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Gacha")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.load()
            // RootView 側で store.configure() 済みなら不要
            // await iap.configure()
        }
        .overlay {
            if vm.isSpinning {
                spinningOverlay
            }
        }
        .sheet(isPresented: resultSheetBinding) {
            resultSheet
        }
    }

    // ✅ result sheet を閉じられる binding にする
    private var resultSheetBinding: Binding<Bool> {
        Binding(
            get: { vm.currentResult != nil },
            set: { isOn in
                if !isOn { vm.closeResult() }
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("チケット")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(vm.tickets)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
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
            }
            .padding(.horizontal)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                pityBar
                if let msg = vm.lastMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
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

            HStack(spacing: 10) {
                Button {
                    vm.drawOnce()
                } label: {
                    Text("単発 (1)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canDraw(count: 1))

                Button {
                    vm.drawTen()
                } label: {
                    Text("10連 (10)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(!vm.canDraw(count: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("提供割合（重み付き）")
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
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var inventoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("所持アイテム")
                .font(.headline)

            LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(vm.ownedDecorations, id: \.item.id) { x in
                    itemCard(
                        title: x.item.name,
                        subtitle: x.item.rarity.rawValue.uppercased(),
                        trailing: "×\(x.count)",
                        isSelected: vm.isSelected(x.item.id),
                        isLocked: false
                    ) {
                        vm.selectDecoration(id: x.item.id)
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
                        subtitle: d.rarity.rawValue.uppercased(),
                        trailing: "欠片 \(cost)",
                        isSelected: vm.isSelected(d.id),
                        isLocked: !affordable
                    ) {
                        vm.exchange(decorationId: d.id)
                    }
                }
            }
        }
    }

    private var bookPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("図鑑（全アイテム）")
                .font(.headline)

            LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(vm.allDecorations, id: \.id) { d in
                    let owned = vm.isOwned(d.id)
                    itemCard(
                        title: d.name,
                        subtitle: d.rarity.rawValue.uppercased(),
                        trailing: owned ? "所持" : "未所持",
                        isSelected: vm.isSelected(d.id),
                        isLocked: !owned
                    ) {
                        if owned { vm.selectDecoration(id: d.id) }
                        else { vm.lastMessage = "未所持です。ガチャで獲得できます" }
                    }
                }
            }
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
            Text("チケット購入")
                .font(.headline)

            switch iap.state {
            case .idle, .loading:
                HStack { ProgressView(); Text("読み込み中…") }
                    .foregroundStyle(.secondary)

            case .failed(let msg):
                Text(msg).foregroundStyle(.secondary)

            case .ready:
                VStack(spacing: 10) {
                    ForEach(iap.products, id: \.id) { p in
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

            if let msg = iap.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            Button("App Storeと同期（復元）") {
                Task { await iap.sync() }
            }
            .padding(.top, 8)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.black.opacity(0.15))
                .frame(width: 46, height: 5)
                .padding(.top, 10)

            if let s = vm.currentResult {
                Text("結果")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("欠片 +\(s.shardsGained) / 天井 \(s.pityAfter)/\(vm.pityMax)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(Array(s.drawn.enumerated()), id: \.offset) { _, d in
                        let isNew = s.newIds.contains(d.id)
                        itemCard(
                            title: d.name,
                            subtitle: d.rarity.rawValue.uppercased(),
                            trailing: isNew ? "NEW" : "dup",
                            isSelected: false,
                            isLocked: false
                        ) {}
                    }
                }
                .padding(.horizontal)

                Button("閉じる") {
                    vm.closeResult()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 16)
            } else {
                Spacer()
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - UI Parts

    private var bannerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ピックアップ（重み付き）")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("天井 + 欠片システム")
                .font(.title3)
                .fontWeight(.bold)
            Text("交換所/履歴/演出を強化して「回したくなる体験」に寄せます")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .fontWeight(.semibold)
                        .lineLimit(1)
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
    }

    private var spinningOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text("回しています…")
                    .font(.headline)
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
