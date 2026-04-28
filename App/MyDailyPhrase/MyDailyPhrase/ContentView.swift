import SwiftUI
import Presentation

struct ContentView: View {
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let settingsVM: SettingsViewModel

    var body: some View {
        NavigationStack {
            HomeView(
                viewModel: homeVM,
                historyViewModel: historyVM,
                settingsViewModel: settingsVM
            )
        }
    }
}
