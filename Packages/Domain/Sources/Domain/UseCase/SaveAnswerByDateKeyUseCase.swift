import Foundation

public struct SaveAnswerByDateKeyUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String, answer: String) {
        guard var entry = entryRepo.getEntry(dateKey: dateKey) else {
            return
        }
        entry.answer = answer
        entryRepo.upsertEntry(entry)
    }
}
