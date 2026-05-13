import SwiftUI
import Presentation

struct ContentView: View {
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let gachaVM: GachaViewModel
    let profileVM: ProfileViewModel
    let settingsVM: SettingsViewModel

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(viewModel: homeVM)
            }
            .tabItem {
                Label("今日", systemImage: "sun.max")
            }

            NavigationStack {
                HistoryView(viewModel: historyVM)
            }
            .tabItem {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                GachaView(vm: gachaVM)
            }
            .tabItem {
                Label("ガチャ", systemImage: "sparkles")
            }

            NavigationStack {
                ProfileView(vm: profileVM, gachaVM: gachaVM)
            }
            .tabItem {
                Label("プロフィール", systemImage: "person.crop.circle")
            }

            NavigationStack {
                SettingsView(viewModel: settingsVM)
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
        }
    }
}
