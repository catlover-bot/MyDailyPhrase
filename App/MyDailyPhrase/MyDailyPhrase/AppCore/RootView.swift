import SwiftUI
import Combine
import Presentation

struct RootView: View {
    private let container: AppContainer
    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let gachaVM: GachaViewModel
    private let profileVM: ProfileViewModel
    private let communityLiteVM: CommunityLiteViewModel
    private let settingsVM: SettingsViewModel
    private let iapStore: IAPStore

    @State private var currentDecorationId = "classic"

    init(container: AppContainer = AppContainer()) {
        self.container = container
        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.gachaVM = container.makeGachaViewModel()
        self.profileVM = container.makeProfileViewModel()
        self.communityLiteVM = container.makeCommunityLiteViewModel()
        self.settingsVM = container.makeSettingsViewModel()
        self.iapStore = container.makeIAPStore()
    }

    var body: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            gachaVM: gachaVM,
            profileVM: profileVM,
            communityLiteVM: communityLiteVM,
            settingsVM: settingsVM
        )
        .environmentObject(iapStore)
        .environment(\.currentDecorationId, currentDecorationId)
        .task {
            homeVM.load()
            historyVM.load()
            gachaVM.load()
            profileVM.load()
            communityLiteVM.load()
            if FeatureFlags.paidGachaEnabled {
                await iapStore.configure()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            homeVM.load()
            historyVM.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            gachaVM.load()
        }
        .onReceive(gachaVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
        .onReceive(profileVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
    }

    private func normalizedDecorationId(_ decorationId: String) -> String {
        let trimmed = decorationId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "classic" : trimmed
    }
}
