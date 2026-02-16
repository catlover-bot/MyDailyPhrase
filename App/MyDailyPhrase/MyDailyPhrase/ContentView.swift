import SwiftUI
import Combine
import Presentation

struct ContentView: View {
    private enum Tab: Hashable {
        case home
        case history
        case review
        case gacha
        case community
        case profile
    }

    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let reviewVM: ReviewViewModel

    @ObservedObject var communityVM: CommunityViewModel
    let profileVM: ProfileViewModel

    // ✅ ガチャVM（共有）
    let gachaVM: GachaViewModel

    let onOpenURL: (URL) -> Void
    @State private var selectedTab: Tab = .home

    private var communityBadge: String? {
        let count = communityVM.unreadInboxCount
        return count > 0 ? String(count) : nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeVM)
                .tabItem { Label("今日", systemImage: "square.and.pencil") }
                .tag(Tab.home)

            HistoryView(viewModel: historyVM)
                .tabItem { Label("履歴", systemImage: "clock") }
                .tag(Tab.history)

            ReviewView(viewModel: reviewVM)
                .tabItem { Label("振り返り", systemImage: "sparkles") }
                .tag(Tab.review)

            // ✅ 追加：ガチャ画面を独立タブに
            NavigationStack {
                GachaView(vm: gachaVM)
            }
            .tabItem { Label("ガチャ", systemImage: "gift") }
            .tag(Tab.gacha)

            CommunityView(vm: communityVM)
                .tabItem { Label("つながり", systemImage: "person.2") }
                .badge(communityBadge)
                .tag(Tab.community)

            NavigationStack {
                ProfileView(vm: profileVM, gachaVM: gachaVM)
            }
            .tabItem { Label("プロフィール", systemImage: "person") }
            .tag(Tab.profile)
        }
        .onOpenURL(perform: onOpenURL)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .community {
                communityVM.markInboxAsRead()
            }
        }
    }
}
