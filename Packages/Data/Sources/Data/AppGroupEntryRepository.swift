import Foundation
import Domain

public final class AppGroupEntryRepository: EntryRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.entries.v1"
    private let corruptBackupKey = "MyDailyPhrase.entries.corrupt.v1"

    private let lock = NSLock()

    public init(appGroupID: String) {
        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
            #if DEBUG
            print("[AppGroupEntryRepository] using suiteName:", appGroupID)
            #endif
        } else {
            self.defaults = .standard
            #if DEBUG
            print("[AppGroupEntryRepository] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
            #endif
        }
    }

    public func getEntry(dateKey: String) -> Entry? {
        withLock {
            let dict = loadDictUnlocked()
            return dict[dateKey]
        }
    }

    public func upsertEntry(_ entry: Entry) {
        withLock {
            var newDict = loadDictUnlocked()
            newDict[entry.dateKey] = entry
            saveDictUnlocked(newDict)

            #if DEBUG
            let after = newDict[entry.dateKey]?.answer
            print("[AppGroupEntryRepository] upsert dateKey=\(entry.dateKey) answer=\(after ?? "nil")")
            #endif
        }
    }

    public func getAllEntries() -> [Entry] {
        withLock {
            let dict = loadDictUnlocked()
            return dict.values.sorted { $0.dateKey > $1.dateKey }
        }
    }

    public func deleteEntry(dateKey: String) {
        withLock {
            var dict = loadDictUnlocked()
            dict.removeValue(forKey: dateKey)
            saveDictUnlocked(dict)
        }
    }

    public func deleteAllEntries() {
        withLock {
            defaults.removeObject(forKey: storeKey)
        }
    }

    // MARK: - Lock helper

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Storage (Unlocked)

    private func loadDictUnlocked() -> [String: Entry] {
        guard let data = defaults.data(forKey: storeKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Entry].self, from: data)
        } catch {
            #if DEBUG
            print("[AppGroupEntryRepository] decode failed:", error)
            #endif
            defaults.set(data, forKey: corruptBackupKey)
            defaults.removeObject(forKey: storeKey)
            return [:]
        }
    }

    private func saveDictUnlocked(_ dict: [String: Entry]) {
        do {
            let data = try JSONEncoder().encode(dict)
            defaults.set(data, forKey: storeKey)
        } catch {
            #if DEBUG
            print("[AppGroupEntryRepository] encode failed:", error)
            #endif
        }
    }
}
