import Foundation

public struct GetEntryByDateKeyUseCase: Sendable {
    private let promptRepo: PromptRepository
    private let entryRepo: EntryRepository

    public init(promptRepo: PromptRepository, entryRepo: EntryRepository) {
        self.promptRepo = promptRepo
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String) -> Entry {
        if let existing = entryRepo.getEntry(dateKey: dateKey) {
            return existing
        }
        let prompt = promptRepo.prompt(for: dateKey)
        return Entry(dateKey: dateKey, prompt: prompt, answer: nil)
    }
}
