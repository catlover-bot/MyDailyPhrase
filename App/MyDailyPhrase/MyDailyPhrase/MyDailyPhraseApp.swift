import SwiftUI
import Domain
import Data
import Presentation

@main
struct MyDailyPhraseApp: App {


    private let appGroupID = "group.jp.catloverbot.MyDailyPhrase"


    var body: some Scene {
        WindowGroup {
            // Data layer
            let entryRepo = AppGroupEntryRepository(appGroupID: appGroupID)
            let promptRepo = LocalPromptRepository()

            // Domain layer
            let getToday = GetTodayEntryUseCase(promptRepo: promptRepo, entryRepo: entryRepo)
            let saveToday = SaveTodayAnswerUseCase(entryRepo: entryRepo)
            let streak = ComputeStreakUseCase(entryRepo: entryRepo)

            // Presentation layer
            let vm = HomeViewModel(
                getTodayEntry: getToday,
                saveTodayAnswer: saveToday,
                computeStreak: streak
            )

            ContentView(viewModel: vm)
        }
    }
}
