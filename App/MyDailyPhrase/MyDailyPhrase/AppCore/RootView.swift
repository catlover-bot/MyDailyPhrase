import SwiftUI
import Combine
import Presentation

struct RootView: View {
    private let container: AppContainer

    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let reviewVM: ReviewViewModel
    private let communityVM: CommunityViewModel
    private let profileVM: ProfileViewModel

    // IAP
    @StateObject private var store: IAPStore

    // Gacha（装飾の唯一の状態源にする）
    @StateObject private var gachaVM: GachaViewModel

    // App全体に配布する装飾ID
    @State private var decorationId: String = "classic"

    init(container: AppContainer = AppContainer()) {
        self.container = container

        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.reviewVM = container.makeReviewViewModel()
        self.communityVM = container.makeCommunityViewModel()
        self.profileVM = container.makeProfileViewModel()

        _store = StateObject(wrappedValue: container.makeIAPStore())
        _gachaVM = StateObject(wrappedValue: container.makeGachaViewModel())

        // decorationId は onAppear / onReceive で確定させる（initで確定しない）
    }

    var body: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            reviewVM: reviewVM,
            communityVM: communityVM,
            profileVM: profileVM,
            gachaVM: gachaVM,
            onOpenURL: { url in
                container.handleIncomingDeepLink(url)
                homeVM.handleOpenURL(url)
                communityVM.refresh()
            }
        )
        // IAP
        .environmentObject(store)
        .task { await store.configure() }

        // Decoration（App全体に配布）
        .environment(\.currentDecorationId, decorationId)

        // 起動時に確実に同期
        .onAppear {
            gachaVM.load()
            decorationId = gachaVM.selectedDecorationId
        }

        // 変更追従：原則 gachaVM を真とする
        .onReceive(gachaVM.$selectedDecorationId.removeDuplicates()) { newId in
            decorationId = newId
        }

        // 保険：Home側で変わる経路が残っている場合のみ拾う（gachaVMが未反映の時だけ）
        .onReceive(homeVM.$selectedDecorationId.removeDuplicates()) { newId in
            if decorationId != newId {
                decorationId = newId
                // 可能なら gachaVM も合わせる（selectDecorationが public なら使う）
                // gachaVM.selectDecoration(id: newId)
            }
        }
    }
}
