import Foundation

public struct SaveTodayAnswerUseCase: Sendable {
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

    public func execute(answer: String) {
        let todayKey = DateKey.todayKey(timeZone: timeZone, now: nowProvider())

        let base: Entry
        if let existing = entryRepo.getEntry(dateKey: todayKey) {
            base = existing
        } else {
            base = Entry(
                dateKey: todayKey,
                prompt: promptRepo.prompt(for: todayKey),
                answer: nil
            )
        }

        var updated = base
        updated.answer = answer
        entryRepo.upsertEntry(updated)
    }
}
