import Foundation

public struct GetTodayEntryUseCase: Sendable {
    private let promptRepo: PromptRepository
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone

    public init(promptRepo: PromptRepository, entryRepo: EntryRepository, timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!) {
        self.promptRepo = promptRepo
        self.entryRepo = entryRepo
        self.timeZone = timeZone
    }

    public func execute() -> Entry {
        let todayKey = DateKey.todayKey(timeZone: timeZone)
        if let existing = entryRepo.getEntry(dateKey: todayKey) {
            return existing
        }
        let prompt = promptRepo.prompt(for: todayKey)
        return Entry(dateKey: todayKey, prompt: prompt, answer: nil)
    }
}
