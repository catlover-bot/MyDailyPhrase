import Foundation

public struct GetTodayEntryUseCase: Sendable {
    private let promptRepo: PromptRepository
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone
    private let nowProvider: @Sendable () -> Date

    public init(
        promptRepo: PromptRepository,
        entryRepo: EntryRepository,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.promptRepo = promptRepo
        self.entryRepo = entryRepo
        self.timeZone = timeZone
        self.nowProvider = nowProvider
    }

    public func execute() -> Entry {
        let todayKey = DateKey.todayKey(timeZone: timeZone, now: nowProvider())
        if let existing = entryRepo.getEntry(dateKey: todayKey) {
            return existing
        }
        let prompt = promptRepo.prompt(for: todayKey)
        return Entry(dateKey: todayKey, prompt: prompt, answer: nil)
    }
}
