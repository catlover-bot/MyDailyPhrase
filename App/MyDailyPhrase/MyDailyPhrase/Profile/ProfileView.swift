import SwiftUI
import StoreKit
import UIKit
import AuthenticationServices
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
            Section("デコ / ガチャ") {
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
                        Label("無料券を受け取る", systemImage: "calendar.badge.plus")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }

                NavigationLink {
                    GachaView(vm: gachaVM)
                } label: {
                    Label("ガチャを開く", systemImage: "sparkles")
                        .compactActionLabel()
                }
            }

            Section("ユーザーID") {
                Text(vm.userId)
                    .font(.footnote)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = vm.userId
                        vm.lastMessage = "User IDをコピーしました"
                    } label: {
                        Label("IDをコピー", systemImage: "doc.on.doc")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: vm.shareProfileText) {
                        Label("プロフィールを共有", systemImage: "square.and.arrow.up")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("招待プログラム") {
                LabeledContent("招待コード") {
                    Text(vm.referralCode)
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                }

                Text("成立時に招待者/被招待者へそれぞれチケット+\(ReferralProgram.inviteeRewardTickets)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = vm.referralCode
                        vm.lastMessage = "招待コードをコピーしました"
                    } label: {
                        Label("コードをコピー", systemImage: "doc.on.doc")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)

                    if let inviteURL = vm.referralInviteURL {
                        ShareLink(item: inviteURL, preview: SharePreview("MyDailyPhrase 招待リンク")) {
                            Label("招待リンクを共有", systemImage: "square.and.arrow.up")
                                .compactActionLabel()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let pending = vm.pendingReferralInvite {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("受信中の招待")
                            .font(.subheadline.weight(.semibold))
                        Text("送信者: \(pending.inviterName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("コード: \(pending.code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        vm.acceptPendingReferralReward()
                    } label: {
                        Label("招待報酬を受け取る", systemImage: "gift.fill")
                            .compactActionLabel()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let ackURL = vm.referralAcknowledgementURL {
                    ShareLink(item: ackURL, preview: SharePreview("招待承認リンク")) {
                        Label("承認リンクを送る", systemImage: "paperplane")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        vm.clearReferralAcknowledgementURL()
                    } label: {
                        Label("承認リンクを破棄", systemImage: "trash")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }

                Text(vm.referralProgressSummaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("プッシュ通知") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("通知状態", systemImage: "bell.badge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(vm.pushAuthorizationStatusText)
                        .font(.subheadline.weight(.semibold))
                    Text("まずは「おすすめ設定」を適用し、不要な通知だけOFFにするのが簡単です。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("シーズン通知の効果")
                        .accessibilityIdentifier("profile.notifications.ab.title")
                        .font(.subheadline.weight(.semibold))
                    Text(vm.notificationABDashboardHintText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if vm.notificationABDashboardRows.allSatisfy({ $0.totalSent == 0 }) {
                        Text("まだ通知データがありません。送信が始まると自動で学習します。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.notificationABDashboardRows) { row in
                            notificationABDashboardCard(row)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        vm.applyRecommendedPushNotificationPreset()
                    } label: {
                        Label("おすすめ設定", systemImage: "sparkles")
                            .compactActionLabel()
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.applyMinimalPushNotificationPreset()
                    } label: {
                        Label("最小限", systemImage: "slider.horizontal.3")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }

                Toggle("通知を有効化", isOn: $vm.pushNotificationsEnabled)
                Toggle("お題更新", isOn: $vm.pushPromptUpdateEnabled)
                    .disabled(!vm.pushNotificationsEnabled)
                Toggle("ミッション達成", isOn: $vm.pushMissionEnabled)
                    .disabled(!vm.pushNotificationsEnabled)
                Toggle("連続記録リマインド", isOn: $vm.pushStreakReminderEnabled)
                    .disabled(!vm.pushNotificationsEnabled)
                Toggle("今週急上昇（バズお題）", isOn: $vm.pushWeeklyTrendEnabled)
                    .disabled(!vm.pushNotificationsEnabled)

                HStack(spacing: 10) {
                    Button {
                        vm.requestPushNotificationPermission()
                    } label: {
                        Label("通知を許可", systemImage: "bell.badge")
                            .compactActionLabel()
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.refreshPushNotificationAuthorizationStatus()
                    } label: {
                        Label("状態を更新", systemImage: "arrow.clockwise")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                }

                Text(vm.pushNotificationSummaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(vm.pushPermissionDisclosureText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !store.isCreatorPassActive {
                    Text("今週急上昇通知は Creator Pass 加入中のみ配信されます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("ログイン / セキュリティ") {
                Text(vm.linkedAuthStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                            vm.lastMessage = "Apple認証情報の取得に失敗しました"
                            return
                        }
                        vm.linkAppleAccount(appleUserID: credential.user, fullName: credential.fullName)
                    case .failure(let error):
                        let ns = error as NSError
                        if ns.domain == ASAuthorizationError.errorDomain,
                           ns.code == ASAuthorizationError.canceled.rawValue {
                            vm.lastMessage = "Appleログインをキャンセルしました"
                        } else {
                            vm.lastMessage = "Appleログインに失敗しました: \(error.localizedDescription)"
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .disabled(vm.isCheckingLinkedAuthState)

                if vm.hasLinkedAuth {
                    Button {
                        vm.verifyLinkedAuthState()
                    } label: {
                        Label(
                            vm.isCheckingLinkedAuthState ? "連携状態を確認中…" : "連携状態を確認",
                            systemImage: "checkmark.shield"
                        )
                        .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isCheckingLinkedAuthState)
                }

                if vm.isGoogleLoginAvailable {
                    Button {
                        Task { await vm.linkGoogleAccountUsingServerToken() }
                    } label: {
                        Label(vm.isLinkingExternalAuth ? "Google連携中…" : "Googleでログイン", systemImage: "g.circle")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLinkingExternalAuth || !vm.canLinkGoogleAccount)
                }

                if vm.isXLoginAvailable {
                    Button {
                        Task { await vm.linkXAccountUsingServerToken() }
                    } label: {
                        Label(vm.isLinkingExternalAuth ? "X連携中…" : "Xでログイン", systemImage: "x.circle")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isLinkingExternalAuth || !vm.canLinkXAccount)
                }

                if vm.canInputExternalAuthTokenManually {
                    SecureField("サーバー検証トークン（開発用）", text: $vm.externalAuthVerificationToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if vm.hasLinkedAuth {
                    Button(role: .destructive) {
                        vm.clearLinkedAccount()
                    } label: {
                        Label("外部連携を解除", systemImage: "link.badge.minus")
                            .compactActionLabel()
                    }
                    .accessibilityIdentifier("profile.auth.unlink")
                }

                Text(vm.externalAuthInputGuideText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("セキュリティログ") {
                Picker("カテゴリ", selection: $vm.securityLogCategoryFilter) {
                    ForEach(ProfileViewModel.SecurityLogCategoryFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("表示", selection: $vm.securityLogFilter) {
                    ForEach(ProfileViewModel.SecurityLogFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Text(vm.securityLogCategoryFilterHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(vm.securityLogFilterHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if vm.filteredSecurityAuditTrail.isEmpty {
                    Text("連携監査ログはまだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(vm.filteredSecurityAuditTrail.prefix(12))) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.securityAuditTitle(event))
                                .font(.subheadline.weight(.semibold))
                            Text(vm.securityAuditSubtitle(event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Picker("削除ポリシー", selection: $vm.securityLogDeletionPolicy) {
                    ForEach(ProfileViewModel.SecurityLogDeletionPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }

                Stepper(
                    "保持日数: \(vm.securityLogRetentionDays)日",
                    value: $vm.securityLogRetentionDays,
                    in: vm.securityLogRetentionRange
                )

                Text(vm.securityRetentionPolicyText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    vm.applySecurityLogDeletionPolicy()
                } label: {
                    Label("削除ポリシーを適用", systemImage: "trash")
                        .compactActionLabel()
                }
                .buttonStyle(.bordered)

                Button {
                    UIPasteboard.general.string = vm.securityAuditReportText
                    vm.lastMessage = "セキュリティログをコピーしました"
                } label: {
                    Label("ログをコピー", systemImage: "doc.on.doc")
                        .compactActionLabel()
                }
                .buttonStyle(.bordered)
            }

            Section("提出チェック") {
                HStack(spacing: 8) {
                    Image(systemName: vm.isSubmissionChecklistPassing ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .foregroundStyle(vm.isSubmissionChecklistPassing ? .green : .red)
                    Text(vm.releaseReadinessSummaryText)
                        .accessibilityIdentifier("profile.releaseReadiness.summary")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    UIPasteboard.general.string = vm.releaseReadinessReportText
                    vm.lastMessage = "提出チェックレポートをコピーしました"
                } label: {
                    Label("提出チェックをコピー", systemImage: "doc.on.doc")
                        .compactActionLabel()
                }
                .buttonStyle(.bordered)

                ForEach(vm.releaseReadinessChecks) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(item.title, systemImage: item.status.icon)
                                .accessibilityIdentifier("profile.releaseReadiness.\(item.id).title")
                                .font(.subheadline.weight(.semibold))
                            if item.required {
                                Text("必須")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text(item.status.title)
                                .accessibilityIdentifier("profile.releaseReadiness.\(item.id).status")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(readinessColor(item.status))
                        }
                        Text(item.detail)
                            .accessibilityIdentifier("profile.releaseReadiness.\(item.id).detail")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("利用規約 / プライバシー") {
                if let termsURL = vm.termsOfServiceURL {
                    Link(destination: termsURL) {
                        Label("利用規約", systemImage: "doc.text")
                    }
                }

                if let privacyURL = vm.privacyPolicyURL {
                    Link(destination: privacyURL) {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                }

                ForEach(vm.legalReadinessNotes, id: \.self) { note in
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("表示名") {
                TextField("表示名", text: $vm.displayName)
                    .textInputAutocapitalization(.words)

                Text(vm.displayNameHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if vm.normalizedDisplayNamePreview != vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines) {
                    HStack {
                        Text("保存後")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.normalizedDisplayNamePreview)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Button("保存") { vm.save() }
                    .disabled(!vm.isDisplayNameChanged)
            }

            Section("アカウント") {
                Card("アカウント情報") {
                    Text(vm.profileSummaryText)
                        .font(.subheadline.weight(.semibold))
                    Text("表示名はコミュニティ共有リンクの送信者名に使われます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let msg = vm.lastMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Paid Gacha（StoreKit2）
            Section("課金 / Creator Pass") {
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Creator Pass")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(store.isCreatorPassActive ? "有効" : "未加入")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(store.isCreatorPassActive ? .green : .secondary)
                            }

                            Text(store.creatorPassStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(store.creatorPassBenefitLines, id: \.self) { line in
                                Label(line, systemImage: "checkmark.seal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if store.creatorPassProducts.isEmpty {
                                Text("Creator Pass商品が未設定です（App Store Connect）")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(store.creatorPassProducts, id: \.id) { p in
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
                        }
                        .padding(.bottom, 6)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("チケットパック")
                                .font(.subheadline.weight(.semibold))
                            ForEach(store.ticketValuePitchLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if store.ticketProducts.isEmpty {
                                Text("チケット商品が未設定です（App Store Connect）")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(store.ticketProducts, id: \.id) { p in
                                    let amount = store.ticketAmount(for: p)
                                    let isBestValue = store.isBestValueTicketProduct(p)
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(p.displayName).font(.headline)
                                                if isBestValue {
                                                    Text("BEST VALUE")
                                                        .font(.caption2.weight(.bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.thinMaterial)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            Text(p.description).font(.caption).foregroundStyle(.secondary)
                                            Text("チケット \(amount)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            if let unitPriceText = store.ticketUnitPriceText(for: p) {
                                                Text(unitPriceText)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
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

                Text("※チケットは購入後すぐに反映されます。Creator Pass は自動更新サブスクリプションで、解約は App Store のアカウント設定から行えます。")
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

    private func readinessColor(_ status: ProfileViewModel.ReleaseReadinessStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .warning:
            return .orange
        case .missing:
            return .red
        }
    }

    private func notificationABDashboardCard(
        _ row: ProfileViewModel.NotificationABDashboardRow
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(row.optimizationLabel)
                    .font(.caption.weight(.semibold))
            }

            Text("\(row.confidenceLabel) / 送信 \(row.totalSent)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("文言別実測")
                .accessibilityIdentifier("profile.notifications.ab.variantHeader.\(row.id)")
                .font(.caption.weight(.semibold))
            ForEach(row.variants) { variant in
                notificationABVariantRowView(variant, compact: false)
            }

            if !row.weekdayRows.isEmpty {
                Divider()
                Text("曜日別実測")
                    .accessibilityIdentifier("profile.notifications.ab.weekdayHeader.\(row.id)")
                    .font(.caption.weight(.semibold))
                ForEach(row.weekdayRows) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(day.weekdayLabel)曜日")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(day.winnerLabel)
                                .font(.caption2.weight(.semibold))
                        }
                        Text("\(day.confidenceLabel) / 送信 \(day.totalSent)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(day.variants) { variant in
                            notificationABVariantRowView(variant, compact: true)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            if !row.timingSlots.isEmpty {
                Divider()
                Text("時間帯別実測（リマインド通知）")
                    .accessibilityIdentifier("profile.notifications.ab.timingHeader.\(row.id)")
                    .font(.caption.weight(.semibold))
                ForEach(row.timingSlots) { slot in
                    notificationTimingRowView(slot, compact: false)
                }

                if !row.timingWeekdayRows.isEmpty {
                    Text("曜日 × 時間帯")
                        .accessibilityIdentifier("profile.notifications.ab.weekdayTimingHeader.\(row.id)")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 2)
                    ForEach(row.timingWeekdayRows) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(day.weekdayLabel)曜日")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(day.optimizationLabel)
                                    .font(.caption2.weight(.semibold))
                            }
                            Text("\(day.confidenceLabel) / 送信 \(day.totalSent)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(day.slots) { slot in
                                notificationTimingRowView(slot, compact: true)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func notificationABVariantRowView(
        _ variant: ProfileViewModel.NotificationABVariantRow,
        compact: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(variant.label)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .frame(width: compact ? 38 : 48, alignment: .leading)
            Text("送信 \(variant.sent)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("開封 \(variant.openRateText)")
                .font(.caption2)
            Text("復帰 \(variant.returnRateText)")
                .font(.caption2)
            Text("総合 \(variant.weightedScoreText)")
                .font(.caption2)
        }
    }

    private func notificationTimingRowView(
        _ slot: ProfileViewModel.NotificationTimingSlotRow,
        compact: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(slot.label)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .frame(width: compact ? 42 : 48, alignment: .leading)
            Text("送信 \(slot.sent)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("開封 \(slot.openRateText)")
                .font(.caption2)
            Text("復帰 \(slot.returnRateText)")
                .font(.caption2)
            Text("総合 \(slot.weightedScoreText)")
                .font(.caption2)
        }
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
