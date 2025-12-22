import Foundation
import Combine
import Domain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var promptText: String = ""
    @Published public var answerText: String = ""
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var isAnsweredToday: Bool = false

    private let getTodayEntry: GetTodayEntryUseCase
    private let saveTodayAnswer: SaveTodayAnswerUseCase
    private let computeStreak: ComputeStreakUseCase

    public init(
        getTodayEntry: GetTodayEntryUseCase,
        saveTodayAnswer: SaveTodayAnswerUseCase,
        computeStreak: ComputeStreakUseCase
    ) {
        self.getTodayEntry = getTodayEntry
        self.saveTodayAnswer = saveTodayAnswer
        self.computeStreak = computeStreak
    }

    public func load() {
        let entry = getTodayEntry.execute()
        promptText = entry.prompt.text
        answerText = entry.answer ?? ""
        isAnsweredToday = (entry.answer?.isEmpty == false)
        streak = computeStreak.execute()
    }

    public func submit() {
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveTodayAnswer.execute(answer: trimmed)
        load()
    }
}
