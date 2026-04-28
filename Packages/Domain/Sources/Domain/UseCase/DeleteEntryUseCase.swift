import Foundation

public struct DeleteEntryUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String) {
        entryRepo.deleteEntry(dateKey: dateKey)
    }
}
