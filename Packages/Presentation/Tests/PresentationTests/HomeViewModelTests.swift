import Foundation
import Testing
import Domain
@testable import Presentation

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test("load populates today's prompt, answer, streak, and monthly count")
    func loadPopulatesState() {
        let repo = InMemoryEntryRepository()
        repo.upsertEntry(makeEntry(dateKey: "20260429", answer: "Saved today"))
        repo.upsertEntry(makeEntry(dateKey: "20260415", answer: "Earlier this month"))
        repo.upsertEntry(makeEntry(dateKey: "20260329", answer: "Last month"))

        let vm = makeViewModel(repo: repo)

        vm.load()

        #expect(vm.todayDateKey == "20260429")
        #expect(vm.promptText == "How would you describe today in one phrase?")
        #expect(vm.answerText == "Saved today")
        #expect(vm.isAnsweredToday == true)
        #expect(vm.streak == 1)
        #expect(vm.answeredThisMonthCount == 2)
    }

    @Test("empty answer is not saved")
    func emptyAnswerIsNotSaved() {
        let repo = InMemoryEntryRepository()
        let vm = makeViewModel(repo: repo)

        vm.load()
        vm.answerText = "   \n"
        vm.submit()

        #expect(repo.getEntry(dateKey: "20260429") == nil)
        #expect(vm.feedbackIsError == true)
    }

    @Test("submit saves a trimmed answer")
    func submitTrimsAndSavesAnswer() {
        let repo = InMemoryEntryRepository()
        let vm = makeViewModel(repo: repo)

        vm.load()
        vm.answerText = "  A focused note  "
        vm.submit()

        #expect(repo.getEntry(dateKey: "20260429")?.answer == "A focused note")
    }

    @Test("answered today state updates after submit")
    func answeredTodayUpdatesAfterSubmit() {
        let repo = InMemoryEntryRepository()
        let vm = makeViewModel(repo: repo)

        vm.load()
        #expect(vm.isAnsweredToday == false)

        vm.answerText = "Done"
        vm.submit()

        #expect(vm.isAnsweredToday == true)
        #expect(vm.saveButtonTitle == "今日の回答を更新")
    }

    private func makeViewModel(repo: InMemoryEntryRepository) -> HomeViewModel {
        let promptRepo = FixedPromptRepository()
        let now = makeDate(year: 2026, month: 4, day: 29)

        let getTodayEntry = GetTodayEntryUseCase(
            promptRepo: promptRepo,
            entryRepo: repo,
            timeZone: timeZone,
            nowProvider: { now }
        )
        let saveTodayAnswer = SaveTodayAnswerUseCase(
            promptRepo: promptRepo,
            entryRepo: repo,
            timeZone: timeZone,
            nowProvider: { now }
        )
        let computeStreak = ComputeStreakUseCase(
            entryRepo: repo,
            timeZone: timeZone,
            nowProvider: { now }
        )
        let countThisMonth = CountAnsweredEntriesInCurrentMonthUseCase(
            entryRepo: repo,
            timeZone: timeZone,
            nowProvider: { now }
        )

        return HomeViewModel(
            getTodayEntry: getTodayEntry,
            saveTodayAnswer: saveTodayAnswer,
            computeStreak: computeStreak,
            countAnsweredEntriesInCurrentMonth: countThisMonth
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeEntry(dateKey: String, answer: String) -> Entry {
        Entry(
            dateKey: dateKey,
            prompt: Prompt(id: "fixed", text: "How would you describe today in one phrase?"),
            answer: answer
        )
    }
}

private struct FixedPromptRepository: PromptRepository {
    func prompt(for dateKey: String) -> Prompt {
        Prompt(id: "fixed-\(dateKey)", text: "How would you describe today in one phrase?")
    }
}

private final class InMemoryEntryRepository: EntryRepository, @unchecked Sendable {
    private var entries: [String: Entry] = [:]

    func getEntry(dateKey: String) -> Entry? {
        entries[dateKey]
    }

    func upsertEntry(_ entry: Entry) {
        entries[entry.dateKey] = entry
    }

    func getAllEntries() -> [Entry] {
        entries.values.sorted { $0.dateKey > $1.dateKey }
    }

    func deleteEntry(dateKey: String) {
        entries.removeValue(forKey: dateKey)
    }

    func deleteAllEntries() {
        entries.removeAll()
    }
}
