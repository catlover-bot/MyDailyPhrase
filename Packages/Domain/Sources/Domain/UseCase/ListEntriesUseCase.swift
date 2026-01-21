import Foundation

public struct ListEntriesUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    /// 新しい日付が先頭
    public func execute() -> [Entry] {
        entryRepo.getAllEntries().sorted { $0.dateKey > $1.dateKey }
    }
}
