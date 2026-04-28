import Foundation
import Testing
@testable import Domain

@Suite("DateKey and Streak")
struct DateKeyAndStreakTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test("todayKey uses the provided time zone")
    func todayKeyUsesProvidedTimeZone() {
        let calendar = makeCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        let utcDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 18, minute: 30))!

        let todayKey = DateKey.todayKey(timeZone: timeZone, now: utcDate)

        #expect(todayKey == "20260429")
    }

    @Test("key formatting is yyyyMMdd")
    func keyFormatting() {
        let calendar = makeCalendar(timeZone: timeZone)
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9, minute: 0))!

        #expect(DateKey.key(of: date, calendar: calendar) == "20260105")
    }

    @Test("date parsing rejects invalid keys")
    func invalidDateKeyReturnsNil() {
        let calendar = makeCalendar(timeZone: timeZone)

        #expect(DateKey.date(from: "20261340", calendar: calendar) == nil)
        #expect(DateKey.date(from: "abc", calendar: calendar) == nil)
    }

    @Test("streak is zero with no entries")
    func streakWithNoEntries() {
        let repo = InMemoryEntryRepository()
        let today = makeDate(year: 2026, month: 4, day: 29)
        let useCase = ComputeStreakUseCase(entryRepo: repo, timeZone: timeZone, nowProvider: { today })

        #expect(useCase.execute() == 0)
    }

    @Test("streak is one with only today answered")
    func streakWithTodayOnly() {
        let repo = InMemoryEntryRepository()
        repo.upsertEntry(answeredEntry(dateKey: "20260429"))

        let today = makeDate(year: 2026, month: 4, day: 29)
        let useCase = ComputeStreakUseCase(entryRepo: repo, timeZone: timeZone, nowProvider: { today })

        #expect(useCase.execute() == 1)
    }

    @Test("streak counts consecutive answered days")
    func streakWithConsecutiveDays() {
        let repo = InMemoryEntryRepository()
        repo.upsertEntry(answeredEntry(dateKey: "20260429"))
        repo.upsertEntry(answeredEntry(dateKey: "20260428"))
        repo.upsertEntry(answeredEntry(dateKey: "20260427"))

        let today = makeDate(year: 2026, month: 4, day: 29)
        let useCase = ComputeStreakUseCase(entryRepo: repo, timeZone: timeZone, nowProvider: { today })

        #expect(useCase.execute() == 3)
    }

    @Test("streak stops at the first gap")
    func streakBreaksOnGap() {
        let repo = InMemoryEntryRepository()
        repo.upsertEntry(answeredEntry(dateKey: "20260429"))
        repo.upsertEntry(answeredEntry(dateKey: "20260427"))

        let today = makeDate(year: 2026, month: 4, day: 29)
        let useCase = ComputeStreakUseCase(entryRepo: repo, timeZone: timeZone, nowProvider: { today })

        #expect(useCase.execute() == 1)
    }

    @Test("deleting an entry updates the computed streak")
    func deletingEntryUpdatesStreak() {
        let repo = InMemoryEntryRepository()
        repo.upsertEntry(answeredEntry(dateKey: "20260429"))
        repo.upsertEntry(answeredEntry(dateKey: "20260428"))
        repo.upsertEntry(answeredEntry(dateKey: "20260427"))

        let today = makeDate(year: 2026, month: 4, day: 29)
        let compute = ComputeStreakUseCase(entryRepo: repo, timeZone: timeZone, nowProvider: { today })
        let delete = DeleteEntryUseCase(entryRepo: repo)

        #expect(compute.execute() == 3)

        delete.execute(dateKey: "20260428")

        #expect(compute.execute() == 1)
    }

    private func makeCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = makeCalendar(timeZone: timeZone)
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func answeredEntry(dateKey: String) -> Entry {
        Entry(
            dateKey: dateKey,
            prompt: Prompt(id: "prompt-\(dateKey)", text: "Prompt"),
            answer: "Saved answer"
        )
    }
}

private final class InMemoryEntryRepository: EntryRepository, @unchecked Sendable {
    private var entries: [String: Entry] = [:]

    func getEntry(dateKey: String) -> Entry? {
        entries[dateKey]
    }

    func upsertEntry(_ entry: Entry) {
        entries[entry.dateKey] = entry
    }

    func getAllEntries() -> [Entry] {
        entries.values.sorted { $0.dateKey > $1.dateKey }
    }

    func deleteEntry(dateKey: String) {
        entries.removeValue(forKey: dateKey)
    }

    func deleteAllEntries() {
        entries.removeAll()
    }
}
