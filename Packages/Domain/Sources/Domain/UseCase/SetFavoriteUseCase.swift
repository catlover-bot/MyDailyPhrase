import Foundation

public struct SetFavoriteUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    public func execute(dateKey: String, isFavorite: Bool) {
        guard var e = entryRepo.getEntry(dateKey: dateKey) else { return }
        e.isFavorite = isFavorite
        entryRepo.upsertEntry(e)
    }
}
