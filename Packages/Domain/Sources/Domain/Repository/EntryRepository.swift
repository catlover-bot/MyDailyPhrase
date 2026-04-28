import Foundation

public protocol EntryRepository: Sendable {
    func getEntry(dateKey: String) -> Entry?
    func upsertEntry(_ entry: Entry)
    func getAllEntries() -> [Entry]
    func deleteEntry(dateKey: String)
    func deleteAllEntries()
}
