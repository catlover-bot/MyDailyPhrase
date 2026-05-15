import SwiftUI
import Presentation

struct ContentView: View {
    private enum RootTab: String, CaseIterable {
        case today
        case gacha
        case community
        case profile
        case settings

        var title: String {
            switch self {
            case .today: return "今日"
            case .gacha: return "ガチャ"
            case .community: return "みんな"
            case .profile: return "プロフィール"
            case .settings: return "設定"
            }
        }

        var systemImage: String {
            switch self {
            case .today: return "sun.max"
            case .gacha: return "sparkles"
            case .community: return "person.2.wave.2"
            case .profile: return "person.crop.circle"
            case .settings: return "gearshape"
            }
        }

        var selectedSystemImage: String {
            switch self {
            case .today: return "sun.max.fill"
            case .gacha: return "sparkles"
            case .community: return "person.2.wave.2.fill"
            case .profile: return "person.crop.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let gachaVM: GachaViewModel
    let profileVM: ProfileViewModel
    let communityLiteVM: CommunityLiteViewModel
    let settingsVM: SettingsViewModel
    @State private var selectedTab: RootTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: homeVM, historyViewModel: historyVM)
            }
            .tag(RootTab.today)
            .tabItem {
                Label("今日", systemImage: "sun.max")
            }

            NavigationStack {
                GachaView(vm: gachaVM)
            }
            .tag(RootTab.gacha)
            .tabItem {
                Label("ガチャ", systemImage: "sparkles")
            }

            NavigationStack {
                CommunityLiteView(vm: communityLiteVM)
            }
            .tag(RootTab.community)
            .tabItem {
                Label("みんな", systemImage: "person.2.wave.2")
            }

            NavigationStack {
                ProfileView(vm: profileVM, gachaVM: gachaVM, communityLiteVM: communityLiteVM)
            }
            .tag(RootTab.profile)
            .tabItem {
                Label("プロフィール", systemImage: "person.crop.circle")
            }

            NavigationStack {
                SettingsView(viewModel: settingsVM)
            }
            .tag(RootTab.settings)
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppBottomTabBar(
                items: RootTab.allCases.map {
                    AppBottomTabBarItem(
                        id: $0,
                        title: $0.title,
                        systemImage: $0.systemImage,
                        selectedSystemImage: $0.selectedSystemImage
                    )
                },
                selection: $selectedTab
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(uiColor: .systemBackground).opacity(0.55),
                        Color(uiColor: .systemBackground).opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
