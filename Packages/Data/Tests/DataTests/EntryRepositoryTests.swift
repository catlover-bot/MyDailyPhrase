import Foundation
import Testing
import Domain
@testable import Data

@Suite("AppGroupEntryRepository")
struct AppGroupEntryRepositoryTests {
    @Test("save and load entry")
    func saveAndLoadEntry() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupEntryRepository(appGroupID: suite)
        let entry = makeEntry(dateKey: "20260429", answer: "A short note")

        repo.upsertEntry(entry)

        #expect(repo.getEntry(dateKey: "20260429") == entry)
    }

    @Test("list entries in descending date order")
    func listEntriesDescending() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupEntryRepository(appGroupID: suite)
        repo.upsertEntry(makeEntry(dateKey: "20260427", answer: "Old"))
        repo.upsertEntry(makeEntry(dateKey: "20260429", answer: "New"))
        repo.upsertEntry(makeEntry(dateKey: "20260428", answer: "Mid"))

        let keys = repo.getAllEntries().map(\.dateKey)

        #expect(keys == ["20260429", "20260428", "20260427"])
    }

    @Test("delete one entry")
    func deleteSingleEntry() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupEntryRepository(appGroupID: suite)
        repo.upsertEntry(makeEntry(dateKey: "20260429", answer: "Keep"))
        repo.upsertEntry(makeEntry(dateKey: "20260428", answer: "Delete"))

        repo.deleteEntry(dateKey: "20260428")

        #expect(repo.getEntry(dateKey: "20260428") == nil)
        #expect(repo.getAllEntries().map(\.dateKey) == ["20260429"])
    }

    @Test("delete all entries")
    func deleteAllEntries() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        let repo = AppGroupEntryRepository(appGroupID: suite)
        repo.upsertEntry(makeEntry(dateKey: "20260429", answer: "One"))
        repo.upsertEntry(makeEntry(dateKey: "20260428", answer: "Two"))

        repo.deleteAllEntries()

        #expect(repo.getAllEntries().isEmpty)
    }

    @Test("corrupt entry data is cleared gracefully and future saves still work")
    func corruptDataDoesNotCrashAndFutureSaveWorks() {
        let suite = makeSuiteName()
        defer { cleanupSuite(suite) }

        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("suiteName failed: \(suite)")
            return
        }

        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: "MyDailyPhrase.entries.v1")

        let repo = AppGroupEntryRepository(appGroupID: suite)

        #expect(repo.getAllEntries().isEmpty)

        let cleanEntry = makeEntry(dateKey: "20260429", answer: "Recovered")
        repo.upsertEntry(cleanEntry)

        #expect(repo.getEntry(dateKey: "20260429") == cleanEntry)
        #expect(defaults.data(forKey: "MyDailyPhrase.entries.corrupt.v1") != nil)
    }

    private func makeSuiteName() -> String {
        "group.MyDailyPhrase.entry.tests.\(UUID().uuidString)"
    }

    private func cleanupSuite(_ suite: String) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    private func makeEntry(dateKey: String, answer: String) -> Entry {
        Entry(
            dateKey: dateKey,
            prompt: Prompt(id: "prompt-\(dateKey)", text: "Prompt \(dateKey)"),
            answer: answer
        )
    }
}
