import Foundation

public struct ComputeStreakUseCase: Sendable {
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
        let entries = entryRepo.getAllEntries()
        let answered = Set(entries.compactMap { e -> String? in
            let a = e.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return a.isEmpty ? nil : e.dateKey
        })

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        var streak = 0
        var cursor = nowProvider()
        while true {
            let key = DateKey.key(for: cursor, timeZone: timeZone)
            if answered.contains(key) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else {
                break
            }
        }
        return streak
    }
}
