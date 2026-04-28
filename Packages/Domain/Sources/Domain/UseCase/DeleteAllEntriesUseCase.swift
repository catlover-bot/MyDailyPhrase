import Foundation

public struct DeleteAllEntriesUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute() {
        entryRepo.deleteAllEntries()
    }
}
