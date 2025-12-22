import Foundation

public struct GetTodayEntryUseCase: Sendable {
    private let promptRepo: PromptRepository
    private let entryRepo: EntryRepository

    public init(promptRepo: PromptRepository, entryRepo: EntryRepository) {
        self.promptRepo = promptRepo
        self.entryRepo = entryRepo
    }

    public func execute(today: Date = Date()) -> DailyEntry {
        let key = DateKey.todayKey(today)
        let prompt = promptRepo.prompt(for: today)
        let answer = entryRepo.loadAnswer(for: key)
        return DailyEntry(dateKey: key, prompt: prompt, answer: answer)
    }
}

public struct SaveTodayAnswerUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(answer: String, today: Date = Date()) {
        let key = DateKey.todayKey(today)
        entryRepo.saveAnswer(answer, for: key)
    }
}

public struct ComputeStreakUseCase: Sendable {
    private let entryRepo: EntryRepository
    private let calendar: Calendar

    public init(entryRepo: EntryRepository, calendar: Calendar = .current) {
        self.entryRepo = entryRepo
        self.calendar = calendar
    }

    public func execute(today: Date = Date()) -> Int {
        let answered = entryRepo.allAnsweredDateKeys()

        var streak = 0
        var cursor = today

        while true {
            let key = DateKey.todayKey(cursor, calendar: calendar)
            if answered.contains(key) {
                streak += 1
                cursor = DateKey.dateByAddingDays(-1, from: cursor, calendar: calendar)
            } else {
                break
            }
        }
        return streak
    }
}
