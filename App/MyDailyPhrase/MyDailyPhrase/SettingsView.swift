import SwiftUI
import Presentation

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @EnvironmentObject private var iap: IAPStore
    @State private var showDeleteConfirmation = false

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
                            InfoBadge(title: vm.appVersionText, systemImage: "number", tint: .green)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            InfoBadge(title: "ローカル保存", systemImage: "lock.fill", tint: .blue)
                            InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                            InfoBadge(title: vm.appVersionText, systemImage: "number", tint: .green)
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
}
