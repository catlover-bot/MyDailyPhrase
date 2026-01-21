import Foundation

public struct ComputeStreakUseCase: Sendable {
    private let entryRepo: EntryRepository
    private let timeZone: TimeZone

    public init(entryRepo: EntryRepository, timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!) {
        self.entryRepo = entryRepo
        self.timeZone = timeZone
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
        var cursor = Date()
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
