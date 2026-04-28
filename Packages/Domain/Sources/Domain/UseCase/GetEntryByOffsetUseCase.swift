import Foundation

public struct GetEntryByOffsetUseCase: Sendable {
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone
    private let nowProvider: @Sendable () -> Date

    public init(
        entryRepo: EntryRepository,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.entryRepo = entryRepo
        self.timeZone = timeZone
        self.nowProvider = nowProvider
    }

    /// 例: -365 で「1年前の今日」
    public func execute(days: Int) -> Entry? {
        let key = DateKey.shiftedKey(from: nowProvider(), days: days, timeZone: timeZone)
        return entryRepo.getEntry(dateKey: key)
    }
}
