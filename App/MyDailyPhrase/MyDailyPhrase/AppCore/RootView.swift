import SwiftUI
import Presentation

struct RootView: View {
    private let container: AppContainer

    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let reviewVM: ReviewViewModel
    private let communityVM: CommunityViewModel
    private let notificationScheduler: AppNotificationScheduler

    @StateObject private var profileVM: ProfileViewModel

    // IAP
    @StateObject private var store: IAPStore

    // Gacha（装飾の唯一の状態源にする）
    @StateObject private var gachaVM: GachaViewModel

    // App全体に配布する装飾ID
    @State private var decorationId: String = "classic"
    @State private var hasBootstrapped = false
    @Environment(\.scenePhase) private var scenePhase
    private let isLoginBypassEnabled: Bool
    private let forceOnboardingForUITest: Bool

    init(container: AppContainer = AppContainer()) {
        self.container = container

        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.reviewVM = container.makeReviewViewModel()
        self.communityVM = container.makeCommunityViewModel()
        self.notificationScheduler = container.makeNotificationScheduler()
        self.isLoginBypassEnabled = Self.boolEnv("UITEST_BYPASS_LOGIN")
        self.forceOnboardingForUITest = Self.boolEnv("UITEST_FORCE_ONBOARDING")

        _profileVM = StateObject(wrappedValue: container.makeProfileViewModel())
        _store = StateObject(wrappedValue: container.makeIAPStore())
        _gachaVM = StateObject(wrappedValue: container.makeGachaViewModel())

        // decorationId は onAppear / onChange で確定させる（initで確定しない）
    }

    var body: some View {
        Group {
            if !hasBootstrapped {
                ProgressView("読み込み中…")
                    .accessibilityIdentifier("root.loading")
            } else if requiresLogin {
                LoginGateView(vm: profileVM)
                    .onOpenURL(perform: handleIncomingURL)
            } else if profileVM.requiresInitialOnboarding || (forceOnboardingForUITest && !profileVM.hasCompletedOnboarding) {
                InitialOnboardingView(profileVM: profileVM) {
                    refreshAllState()
                }
                .onOpenURL(perform: handleIncomingURL)
            } else {
                ContentView(
                    homeVM: homeVM,
                    historyVM: historyVM,
                    reviewVM: reviewVM,
                    communityVM: communityVM,
                    profileVM: profileVM,
                    gachaVM: gachaVM,
                    onOpenURL: handleIncomingURL
                )
            }
        }
        // IAP
        .environmentObject(store)
        .task { await store.configure() }

        // Decoration（App全体に配布）
        .environment(\.currentDecorationId, decorationId)

        // 起動時に確実に同期
        .onAppear {
            bootstrapIfNeeded()
        }

        // 変更追従：gachaVM を唯一の状態源にする
        .onChange(of: gachaVM.selectedDecorationId) { _, newId in
            if decorationId != newId {
                decorationId = newId
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                notificationScheduler.recordAppForeground()
                refreshAllState()
            }
        }
        .onChange(of: profileVM.hasLinkedAuth) { _, linked in
            if linked {
                refreshAllState()
            }
        }
        .onChange(of: profileVM.hasCompletedOnboarding) { _, completed in
            if completed {
                refreshAllState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            homeVM.load()
            notificationScheduler.rescheduleRecurringNotifications(
                promptText: homeVM.promptText,
                isAnsweredToday: homeVM.isAnsweredToday,
                streakDays: homeVM.streak
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareMissionDidUpdate)) { _ in
            homeVM.load()
            notificationScheduler.handleShareMissionUpdate(canClaimReward: homeVM.canClaimShareMissionReward)
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationPreferencesDidUpdate)) { _ in
            notificationScheduler.rescheduleRecurringNotifications(
                promptText: homeVM.promptText,
                isAnsweredToday: homeVM.isAnsweredToday,
                streakDays: homeVM.streak
            )
            notificationScheduler.handleShareMissionUpdate(canClaimReward: homeVM.canClaimShareMissionReward)
            notificationScheduler.handleSeasonMilestoneUpdate(
                weekKey: gachaVM.seasonWeekKey,
                themeTitle: gachaVM.seasonTheme.title,
                currentOwnedCount: gachaVM.seasonLimitedOwnedCount,
                hasClaimableReward: gachaVM.hasClaimableSeasonMilestoneRewards,
                nextRemainingCount: gachaVM.nextSeasonMilestoneRemainingCount
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityTrendDidUpdate)) { notification in
            let prompt = (notification.userInfo?["prompt"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else { return }

            let engagementScore = notification.userInfo?["engagementScore"] as? Int ?? 0
            let postCount = notification.userInfo?["postCount"] as? Int ?? 0
            let reactionCount = notification.userInfo?["reactionCount"] as? Int ?? 0

            notificationScheduler.handleWeeklyTrendUpdate(
                prompt: prompt,
                engagementScore: engagementScore,
                postCount: postCount,
                reactionCount: reactionCount
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .gachaSeasonMilestoneDidUpdate)) { notification in
            let weekKey = (notification.userInfo?["weekKey"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? gachaVM.seasonWeekKey
            let themeTitle = (notification.userInfo?["themeTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? gachaVM.seasonTheme.title
            let currentOwnedCount = notification.userInfo?["currentOwnedCount"] as? Int ?? gachaVM.seasonLimitedOwnedCount
            let hasClaimableReward = notification.userInfo?["hasClaimableReward"] as? Bool ?? gachaVM.hasClaimableSeasonMilestoneRewards
            let nextRemainingCount = notification.userInfo?["nextRemainingCount"] as? Int ?? gachaVM.nextSeasonMilestoneRemainingCount

            notificationScheduler.handleSeasonMilestoneUpdate(
                weekKey: weekKey,
                themeTitle: themeTitle,
                currentOwnedCount: currentOwnedCount,
                hasClaimableReward: hasClaimableReward,
                nextRemainingCount: nextRemainingCount
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationResponseDidReceive)) { notification in
            notificationScheduler.recordNotificationResponse(userInfo: notification.userInfo ?? [:])
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            refreshAllState()
        }
    }

    private var requiresLogin: Bool {
        !isLoginBypassEnabled && !profileVM.hasLinkedAuth
    }

    private func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        Task { @MainActor in
            notificationScheduler.recordAppForeground()
            refreshAllState()
        }
    }

    private func refreshAllState() {
        homeVM.load()
        profileVM.load()
        gachaVM.load()
        communityVM.refresh()
        if decorationId != gachaVM.selectedDecorationId {
            decorationId = gachaVM.selectedDecorationId
        }
        notificationScheduler.rescheduleRecurringNotifications(
            promptText: homeVM.promptText,
            isAnsweredToday: homeVM.isAnsweredToday,
            streakDays: homeVM.streak
        )
        notificationScheduler.handleShareMissionUpdate(canClaimReward: homeVM.canClaimShareMissionReward)
        notificationScheduler.handleSeasonMilestoneUpdate(
            weekKey: gachaVM.seasonWeekKey,
            themeTitle: gachaVM.seasonTheme.title,
            currentOwnedCount: gachaVM.seasonLimitedOwnedCount,
            hasClaimableReward: gachaVM.hasClaimableSeasonMilestoneRewards,
            nextRemainingCount: gachaVM.nextSeasonMilestoneRemainingCount
        )
    }

    private func handleIncomingURL(_ url: URL) {
        container.handleIncomingDeepLink(url)
        homeVM.handleOpenURL(url)
        refreshAllState()
    }

    private static func boolEnv(_ key: String) -> Bool {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return value == "1" || value == "true" || value == "yes"
    }
}
