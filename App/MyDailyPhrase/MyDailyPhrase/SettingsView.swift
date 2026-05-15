import SwiftUI
import Presentation

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
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

                AppSectionCard(
                    title: "データ管理",
                    subtitle: "保存済みの回答と連続記録はこのデバイスにあります。削除すると元に戻せません。"
                ) {
                    Button("すべてのローカルデータを削除", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
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
