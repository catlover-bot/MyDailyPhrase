import Foundation

public struct GetEntryByOffsetUseCase: Sendable {
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone

    public init(entryRepo: EntryRepository, timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!) {
        self.entryRepo = entryRepo
        self.timeZone = timeZone
    }

    /// 例: -365 で「1年前の今日」
    public func execute(days: Int) -> Entry? {
        let key = DateKey.shiftedKey(from: Date(), days: days, timeZone: timeZone)
        return entryRepo.getEntry(dateKey: key)
    }
}
