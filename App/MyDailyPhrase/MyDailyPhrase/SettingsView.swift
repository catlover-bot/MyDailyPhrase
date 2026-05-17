import SwiftUI
import UIKit
import Domain
import Presentation

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @EnvironmentObject private var iap: IAPStore
    @State private var showDeleteConfirmation = false
    @State private var showsIAPDiagnostics = false
    @State private var versionTapCount = 0
    @State private var diagnosticsCopyFeedback: String? = nil
    @State private var artworkPrimaryFilter: GachaArtworkQAPrimaryFilter = .all
    @State private var artworkRarityFilter: GachaArtworkQARarityFilter = .all
    @State private var artworkTypeFilter: GachaArtworkQATypeFilter = .all

    init(viewModel: SettingsViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeroCard(
                    eyebrow: "通知・プライバシー・サポート",
                    title: "設定",
                    subtitle: "このアプリはローカル保存を基本にしています。通知、サポート、データ管理を落ち着いて確認できます。",
                    accent: .blue
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            InfoBadge(title: "ローカル保存", systemImage: "lock.fill", tint: .blue)
                            InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                            versionBadge
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            InfoBadge(title: "ローカル保存", systemImage: "lock.fill", tint: .blue)
                            InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                            versionBadge
                        }
                    }

                    Text(vm.localStorageStatement)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let feedback = vm.feedbackMessage {
                    AppSectionCard(title: "お知らせ") {
                        Text(feedback)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                AppSectionCard(
                    title: "毎日のリマインダー",
                    subtitle: "通知は明示的に有効化したときだけ使われます。許可がない場合は購入や記録には影響しません。"
                ) {
                    Toggle("毎日リマインドする", isOn: reminderToggleBinding)

                    DatePicker(
                        "通知時刻",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(vm.isUpdatingReminder)

                    LabeledContent("通知の状態") {
                        Text(vm.reminderAuthorizationText)
                    }

                    if vm.isUpdatingReminder {
                        ProgressView()
                    }

                    if vm.reminderAuthorizationStatus == .denied {
                        Text("通知が拒否されています。iPhoneの設定アプリから通知を許可するとリマインダーを使えます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                AppSectionCard(
                    title: "プライバシーとサポート",
                    subtitle: "利用ルールや問い合わせ先をここから確認できます。"
                ) {
                    Link(destination: vm.privacyPolicyURL) {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }

                    Link(destination: vm.supportURL) {
                        Label("サポート", systemImage: "questionmark.circle")
                    }
                }

                if FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled {
                    AppSectionCard(
                        title: "購入と復元",
                        subtitle: "価格情報の再読み込みや購入情報の復元はここから行えます。外部決済リンクは使っていません。"
                    ) {
                        Text(iap.productStatusTitle)
                            .font(.subheadline.weight(.semibold))

                        Text(iap.productStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let message = iap.lastMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

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

                        Text("ガチャは装飾アイテム専用で、現金価値はありません。購入前に確率を確認できます。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(iap.storefrontPricingHelpText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if showsIAPDiagnostics {
                        AppSectionCard(
                            title: "購入診断情報",
                            subtitle: "TestFlight で価格が出ないときに、どの商品 ID が読み込めていないかを確認できます。"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                diagnosticRow(title: "状態", value: iap.productStatusTitle)
                                diagnosticRow(title: "同期状況", value: iap.eventStatusText)
                                diagnosticRow(title: "要求した商品 ID", value: joinedDiagnosticText(iap.storeDiagnosticsSnapshot.requestedProductIDs))
                                diagnosticRow(title: "読み込めた商品 ID", value: joinedDiagnosticText(iap.storeDiagnosticsSnapshot.loadedProductIDs))
                                diagnosticRow(title: "未取得の商品 ID", value: joinedDiagnosticText(iap.storeDiagnosticsSnapshot.missingProductIDs))
                                diagnosticRow(title: "商品数", value: "\(iap.storeDiagnosticsSnapshot.productCount)")
                                diagnosticRow(title: "Storefront 国コード", value: iap.storeDiagnosticsSnapshot.storefrontCountryCode ?? "取得不可")
                                diagnosticRow(title: "Storefront ID", value: iap.storeDiagnosticsSnapshot.storefrontIdentifier ?? "取得不可")
                                diagnosticRow(title: "Storefront 通貨", value: iap.storeDiagnosticsSnapshot.storefrontCurrencyCode ?? "取得不可")
                                diagnosticRow(title: "端末 Locale", value: iap.storeDiagnosticsSnapshot.deviceLocaleIdentifier)
                                diagnosticRow(title: "端末通貨", value: iap.storeDiagnosticsSnapshot.deviceCurrencyCode ?? "取得不可")
                                diagnosticRow(title: "アプリ言語", value: joinedDiagnosticText(iap.storeDiagnosticsSnapshot.appPreferredLanguages))
                                diagnosticRow(title: "最終更新", value: iap.storeDiagnosticsSnapshot.lastRefreshText ?? "まだありません")
                                diagnosticRow(title: "最終復元", value: iap.storeDiagnosticsSnapshot.lastSyncText ?? "まだありません")
                                diagnosticRow(title: "Creator Pass", value: iap.storeDiagnosticsSnapshot.creatorPassStatusText)
                                diagnosticRow(title: "最後のエラー", value: iap.storeDiagnosticsSnapshot.lastStoreKitError ?? "なし")
                                diagnosticCodeBlock(
                                    title: "読み込めた商品詳細",
                                    value: joinedLoadedProductText(iap.storeDiagnosticsSnapshot.loadedProducts)
                                )

                                Button {
                                    UIPasteboard.general.string = iap.diagnosticsReportText
                                    diagnosticsCopyFeedback = "診断情報をコピーしました"
                                } label: {
                                    Label("診断情報をコピー", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                if let diagnosticsCopyFeedback {
                                    Text(diagnosticsCopyFeedback)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if showsIAPDiagnostics {
                    AppSectionCard(
                        title: "ガチャアート確認",
                        subtitle: "未所持のアイテムも含めて、assets.xcassets に登録したアートがこの端末で見えているか確認できます。"
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("通常のコレクション画面では、所持・未所持の扱いはこれまで通りです。ここではアート確認のために全アイテムを一覧できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            artworkPrimaryFilterChips

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) {
                                    artworkRarityPicker
                                    artworkTypePicker
                                }

                                VStack(spacing: 10) {
                                    artworkRarityPicker
                                    artworkTypePicker
                                }
                            }

                            ForEach(Array(artworkRowSections.enumerated()), id: \.offset) { _, section in
                                if !section.rows.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(section.title) (\(section.rows.count))")
                                            .font(.subheadline.weight(.semibold))

                                        ForEach(section.rows) { row in
                                            GachaArtworkDiagnosticCard(row: row)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                AppSectionCard(
                    title: "データ管理",
                    subtitle: "保存済みの回答と連続記録はこのデバイスにあります。削除すると元に戻せません。"
                ) {
                    Button("すべてのローカルデータを削除", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)

                    Text("日記、コミュニティ下書き、ローカルDMの保存内容がこの端末から削除されます。購入そのものには影響しません。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: AppChrome.standardPageMaxWidth)
            .padding(.horizontal, AppChrome.screenHorizontalPadding)
            .padding(.top, AppChrome.standardPageTopPadding)
            .padding(.bottom, AppChrome.standardPageBottomPadding)
        }
        .background(AppScreenBackground())
        .navigationTitle("設定")
        .confirmationDialog(
            "すべてのローカルデータを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                vm.deleteAllData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は元に戻せません。")
        }
        .task {
            await vm.load()
        }
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding(
            get: { vm.reminderEnabled },
            set: { newValue in
                Task {
                    await vm.setReminderEnabled(newValue)
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { vm.reminderTime },
            set: { newValue in
                Task {
                    await vm.setReminderTime(newValue)
                }
            }
        )
    }

    private var versionBadge: some View {
        Button {
            versionTapCount += 1
            if versionTapCount >= 5 {
                showsIAPDiagnostics.toggle()
                versionTapCount = 0
            }
        } label: {
            InfoBadge(title: vm.appVersionText, systemImage: "number", tint: .green)
        }
        .buttonStyle(.plain)
    }

    private var artworkAllRows: [GachaArtworkQAItemRow] {
        GachaArtworkQASupport.rows(
            ownedDecorationIDs: Set(vm.ownedDecorationIDs),
            equippedDecorationID: vm.equippedDecorationID,
            hasBundledArtwork: { decorationID in
                DecorationBundledArtworkCatalog.hasBundledArtwork(for: decorationID)
            }
        )
    }

    private var filteredArtworkRows: [GachaArtworkQAItemRow] {
        GachaArtworkQASupport.filteredRows(
            from: artworkAllRows,
            primaryFilter: artworkPrimaryFilter,
            rarityFilter: artworkRarityFilter,
            typeFilter: artworkTypeFilter
        )
    }

    private var artworkRowSections: [(title: String, rows: [GachaArtworkQAItemRow])] {
        if artworkPrimaryFilter == .all,
           artworkRarityFilter == .all,
           artworkTypeFilter == .all {
            let order: [GachaArtworkQAAssetStatus] = [.available, .mappedMissing, .fallbackOnly]
            return order.compactMap { status in
                let rows = filteredArtworkRows.filter { $0.assetStatus == status }
                guard !rows.isEmpty else { return nil }
                return (status.label, rows)
            }
        }

        return [(artworkPrimaryFilter.rawValue, filteredArtworkRows)]
    }

    private var artworkPrimaryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GachaArtworkQAPrimaryFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            artworkPrimaryFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                artworkPrimaryFilter == filter
                                ? Color.accentColor.opacity(0.16)
                                : Color(uiColor: .secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(artworkPrimaryFilter == filter ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private var artworkRarityPicker: some View {
        Picker("レアリティ", selection: $artworkRarityFilter) {
            ForEach(GachaArtworkQARarityFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.menu)
    }

    private var artworkTypePicker: some View {
        Picker("種類", selection: $artworkTypeFilter) {
            ForEach(GachaArtworkQATypeFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.menu)
    }

    private func diagnosticRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticCodeBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func joinedDiagnosticText(_ items: [String]) -> String {
        items.isEmpty ? "なし" : items.joined(separator: "\n")
    }

    private func joinedLoadedProductText(_ items: [StoreProductDiagnosticsSnapshot.ProductLine]) -> String {
        guard !items.isEmpty else { return "なし" }
        return items.map { item in
            [
                item.productID,
                "  name: \(item.displayName)",
                "  displayPrice: \(item.displayPrice ?? "取得不可")",
                "  currencyCode: \(item.currencyCode ?? "取得不可")",
                "  priceLocale: \(item.localeIdentifier ?? "取得不可")"
            ].joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }
}

private struct GachaArtworkDiagnosticCard: View {
    let row: GachaArtworkQAItemRow

    private var item: CardDecoration? {
        CardDecorationCatalog.byId(row.id)
    }

    private var assetNameText: String {
        let names = [row.assetName, row.thumbnailAssetName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return names.isEmpty ? "未設定" : names.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    titleBlock
                    Spacer(minLength: 0)
                    statusBadges
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    statusBadges
                }
            }

            if let item {
                GachaArtworkView(
                    item: item,
                    displayMode: .diagnostics
                )
            }

            metadataGrid

            VStack(alignment: .leading, spacing: 4) {
                Text("assetName / thumbnailAssetName")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(assetNameText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !row.applicableSurfaceLabels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("使える場所")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlexibleSurfaceChips(labels: row.applicableSurfaceLabels)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.displayName)
                .font(.headline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text(row.id)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var statusBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                diagnosticBadge(title: row.assetStatus.label, tint: statusTint)
                if row.isOwned {
                    diagnosticBadge(title: "所持", tint: .blue)
                }
                if row.isEquipped {
                    diagnosticBadge(title: "装備中", tint: .green)
                }
            }

            Text(statusDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metadataGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], alignment: .leading, spacing: 10) {
            metadataCell(title: "レアリティ", value: row.rarityLabel)
            metadataCell(title: "重み", value: "\(row.weight)")
            metadataCell(title: "種類", value: row.itemTypeLabel)
            metadataCell(title: "排出対象", value: row.isInNormalGachaPool ? "はい" : "いいえ")
            metadataCell(title: "季節限定", value: row.isSeasonLimited ? "はい" : "いいえ")
            metadataCell(title: "状態", value: row.isOwned ? (row.isEquipped ? "所持 / 装備中" : "所持") : "未所持")
        }
    }

    private func metadataCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusTint: Color {
        switch row.assetStatus {
        case .available:
            return .green
        case .mappedMissing:
            return .orange
        case .fallbackOnly:
            return .secondary
        }
    }

    private var statusDescription: String {
        switch row.assetStatus {
        case .available:
            return "この端末で画像が見つかりました。"
        case .mappedMissing:
            return "assetName はありますが、画像が見つからないためフォールバック表示になります。"
        case .fallbackOnly:
            return "まだ画像参照はなく、SwiftUI のフォールバック表示を使います。"
        }
    }

    private func diagnosticBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}
