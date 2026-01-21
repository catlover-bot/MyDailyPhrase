import SwiftUI
import Presentation

struct RootView: View {
    private let container: AppContainer

    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let reviewVM: ReviewViewModel
    private let communityVM: CommunityViewModel
    private let profileVM: ProfileViewModel

    init(container: AppContainer = AppContainer()) {
        self.container = container

        let h = container.makeHomeViewModel()
        self.homeVM = h
        self.historyVM = container.makeHistoryViewModel()
        self.reviewVM = container.makeReviewViewModel()
        self.communityVM = container.makeCommunityViewModel()
        self.profileVM = container.makeProfileViewModel()
    }

    var body: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            reviewVM: reviewVM,
            communityVM: communityVM,
            profileVM: profileVM,
            onOpenURL: { url in
                // 1) イベント保存（inbox/outbox を増やす）
                container.handleIncomingDeepLink(url)

                // 2) UI側の動作（Challenge sheet など）
                homeVM.handleOpenURL(url)

                // 3) Community も即更新
                communityVM.refresh()
            }
        )
    }
}
