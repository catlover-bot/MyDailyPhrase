import SwiftUI
import Presentation

struct RootView: View {
    private let container: AppContainer
    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let settingsVM: SettingsViewModel

    init(container: AppContainer = AppContainer()) {
        self.container = container
        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.settingsVM = container.makeSettingsViewModel()
    }

    var body: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            settingsVM: settingsVM
        )
        .task {
            homeVM.load()
            historyVM.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            homeVM.load()
            historyVM.load()
        }
    }
}
