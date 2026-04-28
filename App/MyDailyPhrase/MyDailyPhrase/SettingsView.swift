import SwiftUI
import Presentation

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @State private var showDeleteConfirmation = false

    init(viewModel: SettingsViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            if let feedback = vm.feedbackMessage {
                Section {
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("このアプリについて") {
                LabeledContent("アプリ版") {
                    Text(vm.appVersionText)
                }

                Text(vm.localStorageStatement)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("毎日のリマインダー") {
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

            Section("プライバシーとサポート") {
                Link("プライバシーポリシー", destination: vm.privacyPolicyURL)
                Link("サポート", destination: vm.supportURL)
            }

            Section {
                Button("すべてのローカルデータを削除", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } header: {
                Text("データ")
            } footer: {
                Text("削除すると、保存済みの回答と連続記録はこのデバイスから消去されます。")
            }
        }
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
