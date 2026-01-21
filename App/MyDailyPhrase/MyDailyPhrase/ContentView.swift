import SwiftUI
import Presentation

struct ContentView: View {
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let reviewVM: ReviewViewModel

    // 追加
    let communityVM: CommunityViewModel
    let profileVM: ProfileViewModel

    // 追加：deep link を統合処理
    let onOpenURL: (URL) -> Void

    var body: some View {
        TabView {
            HomeView(viewModel: homeVM)
                .tabItem { Label("今日", systemImage: "square.and.pencil") }

            HistoryView(viewModel: historyVM)
                .tabItem { Label("履歴", systemImage: "clock") }

            ReviewView(viewModel: reviewVM)
                .tabItem { Label("振り返り", systemImage: "sparkles") }

            CommunityView(vm: communityVM)
                .tabItem { Label("つながり", systemImage: "person.2") }

            NavigationStack {
                ProfileView(vm: profileVM)
            }
            .tabItem { Label("プロフィール", systemImage: "person") }
        }
        .onOpenURL(perform: onOpenURL)
    }
}
