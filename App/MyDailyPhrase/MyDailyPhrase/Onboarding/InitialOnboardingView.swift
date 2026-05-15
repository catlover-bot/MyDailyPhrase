import SwiftUI

struct InitialOnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case profile
        case growth

        var title: String {
            switch self {
            case .welcome:
                return "ようこそ"
            case .profile:
                return "プロフィール"
            case .growth:
                return "つながり"
            }
        }
    }

    @ObservedObject var profileVM: ProfileViewModel
    let onFinished: () -> Void

    @State private var step: Step = .welcome
    @State private var displayNameDraft: String = ""
    @State private var notificationsEnabled: Bool = true
    @State private var promptUpdateEnabled: Bool = true
    @State private var missionEnabled: Bool = true
    @State private var streakReminderEnabled: Bool = true
    @State private var weeklyTrendEnabled: Bool = true
    @State private var wantsPushPermission: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.09),
                    Color.cyan.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                card
                controls
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .onAppear {
            if displayNameDraft.isEmpty {
                displayNameDraft = profileVM.displayName
            }
            notificationsEnabled = profileVM.pushNotificationsEnabled
            promptUpdateEnabled = profileVM.pushPromptUpdateEnabled
            missionEnabled = profileVM.pushMissionEnabled
            streakReminderEnabled = profileVM.pushStreakReminderEnabled
            weeklyTrendEnabled = profileVM.pushWeeklyTrendEnabled
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("初回セットアップ")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("onboarding.title")
                Spacer()
                Button("あとで") {
                    finish()
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("onboarding.skip")
            }

            Text("Step \(step.rawValue + 1) / \(Step.allCases.count) · \(step.title)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(.blue)
        }
    }

    @ViewBuilder
    private var card: some View {
        switch step {
        case .welcome:
            VStack(alignment: .leading, spacing: 10) {
                Text("今日のひとことから始めましょう。")
                    .font(.title3.weight(.semibold))

                Text("1日1つのお題に答えるだけで、その日の記録がこの端末に残ります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("回答は自動で公開されません。共有する内容も、送る前に自分で選べます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .profile:
            VStack(alignment: .leading, spacing: 10) {
                Text("表示名を設定")
                    .font(.title3.weight(.semibold))
                TextField("表示名", text: $displayNameDraft)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.displayName")

                Text("保存後プレビュー: \(previewDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .growth:
            VStack(alignment: .leading, spacing: 12) {
                Text("続けやすい設定")
                    .font(.title3.weight(.semibold))

                Text("通知をONにすると、毎日の記録や無料ガチャの確認を忘れにくくなります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(profileVM.pushAuthorizationStatusText, systemImage: "bell.badge")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("おすすめ") {
                        notificationsEnabled = true
                        promptUpdateEnabled = true
                        missionEnabled = true
                        streakReminderEnabled = true
                        weeklyTrendEnabled = true
                        wantsPushPermission = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("最小限") {
                        notificationsEnabled = true
                        promptUpdateEnabled = true
                        missionEnabled = false
                        streakReminderEnabled = true
                        weeklyTrendEnabled = false
                        wantsPushPermission = true
                    }
                    .buttonStyle(.bordered)
                }

                Toggle("通知を有効化", isOn: $notificationsEnabled)

                if notificationsEnabled {
                    Toggle("お題更新", isOn: $promptUpdateEnabled)
                    Toggle("ミッション達成", isOn: $missionEnabled)
                    Toggle("連続記録リマインド", isOn: $streakReminderEnabled)
                    Toggle("週のまとめ通知", isOn: $weeklyTrendEnabled)
                    Toggle("完了時に通知許可ダイアログを表示", isOn: $wantsPushPermission)
                        .font(.subheadline)
                    Button {
                        profileVM.requestPushNotificationPermission()
                        wantsPushPermission = false
                    } label: {
                        Label("今すぐ通知を許可", systemImage: "bell.badge.fill")
                            .compactActionLabel()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("通知をOFFにするとリマインドは届きません。後からプロフィールで変更できます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("ガチャで集めたテーマはプロフィールや共有カードに反映され、みんなの部屋には無料で参加できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if step != .welcome {
                Button("戻る") {
                    step = Step(rawValue: max(0, step.rawValue - 1)) ?? .welcome
                }
                .buttonStyle(.bordered)
            }

            Button(step == .growth ? "はじめる" : "次へ") {
                if step == .growth {
                    finish()
                    return
                }
                step = Step(rawValue: min(Step.allCases.count - 1, step.rawValue + 1)) ?? .growth
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(step == .growth ? "onboarding.finish" : "onboarding.next")
        }
    }

    private var previewDisplayName: String {
        let trimmed = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Me" : trimmed
    }

    private func finish() {
        let notificationPlan = ProfileViewModel.OnboardingNotificationPlan(
            isEnabled: notificationsEnabled,
            promptUpdateEnabled: promptUpdateEnabled,
            missionEnabled: missionEnabled,
            streakReminderEnabled: streakReminderEnabled,
            weeklyTrendEnabled: weeklyTrendEnabled,
            requestPermission: notificationsEnabled && wantsPushPermission
        )
        profileVM.completeInitialOnboarding(preferredDisplayName: displayNameDraft, notificationPlan: notificationPlan)
        onFinished()
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
