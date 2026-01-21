import Foundation

public struct SaveTodayAnswerUseCase: Sendable {
    private let promptRepo: PromptRepository
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone

    public init(
        promptRepo: PromptRepository,
        entryRepo: EntryRepository,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!
    ) {
        self.promptRepo = promptRepo
        self.entryRepo = entryRepo
        self.timeZone = timeZone
    }

    public func execute(answer: String) {
        let todayKey = DateKey.todayKey(timeZone: timeZone)

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
