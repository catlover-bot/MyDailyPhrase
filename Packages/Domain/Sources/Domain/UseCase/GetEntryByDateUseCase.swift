import Foundation

public struct GetEntryByDateUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String) -> Entry? {
        entryRepo.getEntry(dateKey: dateKey)
    }
}
