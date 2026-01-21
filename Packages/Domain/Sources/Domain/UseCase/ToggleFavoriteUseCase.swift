import Foundation

public struct ToggleFavoriteUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String) {
        guard var e = entryRepo.getEntry(dateKey: dateKey) else { return }
        e.isFavorite.toggle()
        entryRepo.upsertEntry(e)
    }
}
