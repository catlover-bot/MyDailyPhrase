import SwiftUI
import Combine
import Presentation

struct ContentView: View {
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let reviewVM: ReviewViewModel

    let communityVM: CommunityViewModel
    let profileVM: ProfileViewModel

    // ✅ ガチャVM（共有）
    let gachaVM: GachaViewModel

    let onOpenURL: (URL) -> Void

    var body: some View {
        TabView {
            HomeView(viewModel: homeVM)
                .tabItem { Label("今日", systemImage: "square.and.pencil") }

            HistoryView(viewModel: historyVM)
                .tabItem { Label("履歴", systemImage: "clock") }

            ReviewView(viewModel: reviewVM)
                .tabItem { Label("振り返り", systemImage: "sparkles") }

            // ✅ 追加：ガチャ画面を独立タブに
            NavigationStack {
                GachaView(vm: gachaVM)
            }
            .tabItem { Label("ガチャ", systemImage: "gift") }

            CommunityView(vm: communityVM)
                .tabItem { Label("つながり", systemImage: "person.2") }

            NavigationStack {
                ProfileView(vm: profileVM, gachaVM: gachaVM)
            }
            .tabItem { Label("プロフィール", systemImage: "person") }
        }
        .onOpenURL(perform: onOpenURL)
    }
}
