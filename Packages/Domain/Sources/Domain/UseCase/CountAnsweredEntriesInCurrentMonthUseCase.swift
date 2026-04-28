import Foundation

public struct CountAnsweredEntriesInCurrentMonthUseCase: Sendable {
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

    public func execute() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentMonth = calendar.dateComponents([.year, .month], from: nowProvider())

        return entryRepo.getAllEntries().reduce(into: 0) { count, entry in
            let trimmedAnswer = entry.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedAnswer.isEmpty else { return }
            guard let date = DateKey.date(from: entry.dateKey, calendar: calendar) else { return }

            let month = calendar.dateComponents([.year, .month], from: date)
            if month.year == currentMonth.year, month.month == currentMonth.month {
                count += 1
            }
        }
    }
}
