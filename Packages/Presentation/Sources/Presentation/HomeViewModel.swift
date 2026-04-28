import Foundation
import Domain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var promptText: String = ""
    @Published public private(set) var todayDateKey: String = ""
    @Published public var answerText: String = ""
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var isAnsweredToday: Bool = false
    @Published public private(set) var answeredThisMonthCount: Int = 0
    @Published public private(set) var feedbackMessage: String? = nil
    @Published public private(set) var feedbackIsError: Bool = false
    @Published public private(set) var isLoading: Bool = false

    private let getTodayEntry: GetTodayEntryUseCase
    private let saveTodayAnswer: SaveTodayAnswerUseCase
    private let computeStreak: ComputeStreakUseCase
    private let countAnsweredEntriesInCurrentMonth: CountAnsweredEntriesInCurrentMonthUseCase

    public init(
        getTodayEntry: GetTodayEntryUseCase,
        saveTodayAnswer: SaveTodayAnswerUseCase,
        computeStreak: ComputeStreakUseCase,
        countAnsweredEntriesInCurrentMonth: CountAnsweredEntriesInCurrentMonthUseCase
    ) {
        self.getTodayEntry = getTodayEntry
        self.saveTodayAnswer = saveTodayAnswer
        self.computeStreak = computeStreak
        self.countAnsweredEntriesInCurrentMonth = countAnsweredEntriesInCurrentMonth
    }

    public var saveButtonTitle: String {
        isAnsweredToday ? "今日の回答を更新" : "今日の回答を保存"
    }

    public func load() {
        isLoading = true
        defer { isLoading = false }
        clearFeedback()

        let entry = getTodayEntry.execute()
        let trimmedAnswer = entry.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        todayDateKey = entry.dateKey
        promptText = entry.prompt.text
        answerText = entry.answer ?? ""
        isAnsweredToday = !trimmedAnswer.isEmpty
        streak = computeStreak.execute()
        answeredThisMonthCount = countAnsweredEntriesInCurrentMonth.execute()
    }

    public func submit() {
        let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            feedbackMessage = "回答を入力してから保存してください"
            feedbackIsError = true
            return
        }

        saveTodayAnswer.execute(answer: trimmedAnswer)
        load()
        answerText = trimmedAnswer
        feedbackMessage = isAnsweredToday ? "今日の回答を保存しました" : "保存しました"
        feedbackIsError = false
        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
    }

    public func clearFeedback() {
        feedbackMessage = nil
        feedbackIsError = false
    }
}
