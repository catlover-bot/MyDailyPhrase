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
                Text("記録を安全に続ける準備ができました。")
                    .font(.title3.weight(.semibold))

                Text("\(profileVM.linkedAuthProviderName) で連携済みです。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("このあと表示名と通知設定を整えると、共有・招待・ランキング機能をすぐ使えます。")
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
                Text("通知と招待の準備")
                    .font(.title3.weight(.semibold))

                Text("通知をONにすると、報酬や連続記録の取りこぼしを防げます。")
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
                    Toggle("今週急上昇（Creator Pass）", isOn: $weeklyTrendEnabled)
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
                    Text("通知をOFFにするとリマインドは届きません。後から Profile で変更できます。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("招待コード \(profileVM.referralCode) を共有すると、招待成立時に双方へ報酬があります。")
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
        lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}
