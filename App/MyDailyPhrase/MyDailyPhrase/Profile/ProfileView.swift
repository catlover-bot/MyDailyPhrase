import SwiftUI
import StoreKit
import Domain

struct ProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @ObservedObject var gachaVM: GachaViewModel

    @EnvironmentObject private var store: IAPStore
    @Environment(\.currentDecorationId) private var decorationId

    init(vm: ProfileViewModel, gachaVM: GachaViewModel) {
        self.vm = vm
        self.gachaVM = gachaVM
    }

    private var equippedName: String {
        CardDecorationCatalog.byId(decorationId)?.name ?? decorationId
    }

    var body: some View {
        Form {
            Section("Decoration / Gacha") {
                // 現在の装飾プレビュー（Environmentに追従）
                Card("現在選択中：\(equippedName)", decorationId: decorationId) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("この雰囲気がアプリ内カードに反映されます")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("サンプル")
                            .font(.headline)
                    }
                }

                // ✅ ガチャの現況をプロフィールでも見える化
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("チケット \(gachaVM.tickets)", systemImage: "ticket")
                        Spacer()
                        Label("欠片 \(gachaVM.shards)", systemImage: "seal")
                    }
                    .font(.subheadline)

                    HStack {
                        Text("天井 \(gachaVM.pity)/\(gachaVM.pityMax)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("バナー：\(gachaVM.currentBanner.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        gachaVM.grantDailyTicketIfNeeded()
                    } label: {
                        Label("デイリー無料券を受け取る", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }

                NavigationLink {
                    GachaView(vm: gachaVM)
                } label: {
                    Label("ガチャへ（装飾を変更）", systemImage: "sparkles")
                }
            }

            Section("Your ID") {
                Text(vm.userId)
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            Section("Display Name") {
                TextField("表示名", text: $vm.displayName)
                Button("保存") { vm.save() }
            }

            // Paid Gacha（StoreKit2）
            Section("Paid Gacha") {
                switch store.state {
                case .idle, .loading:
                    HStack {
                        ProgressView()
                        Text("商品情報を読み込み中…")
                            .foregroundStyle(.secondary)
                    }

                case .failed(let msg):
                    Text(msg).foregroundStyle(.secondary)
                    Button("再読み込み") {
                        Task { await store.loadProducts() }
                    }

                case .ready:
                    if store.products.isEmpty {
                        Text("商品がありません（Product ID / App Store Connect設定を確認）")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.products, id: \.id) { p in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.displayName).font(.headline)
                                    Text(p.description).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(p.displayPrice) {
                                    Task { await store.purchase(p) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button("App Storeと同期") {
                        Task { await store.sync() }
                    }
                    .buttonStyle(.bordered)
                }

                if let m = store.lastMessage, !m.isEmpty {
                    Text(m).font(.footnote).foregroundStyle(.secondary)
                }

                Text("※消耗型（Consumable）としてガチャ券を付与します。無料券と同じ「ガチャ券」に合算されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            vm.load()
            gachaVM.load()
            // RootView側で store.configure() を実行している前提。
            // もし未実行の可能性があるなら、ここで store.loadProducts() を呼ぶ程度に留めるのが安全。
        }
    }
}
