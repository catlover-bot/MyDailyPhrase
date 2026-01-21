import Foundation
import Domain

public final class AppGroupEntryRepository: EntryRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.entries.v1"
    private let appGroupID: String

    private let lock = NSLock()

    public init(appGroupID: String) {
        self.appGroupID = appGroupID
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
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return nil }
            return dict[dateKey]
        }
    }

    public func upsertEntry(_ entry: Entry) {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            // decode 失敗時に空dictで上書きして“全消し”になるのを防ぐ
            guard !hadError else {
                #if DEBUG
                print("[AppGroupEntryRepository] decode failed previously; abort upsert to avoid wiping store.")
                #endif
                return
            }

            var newDict = dict
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
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return [] }
            return dict.values.sorted { $0.dateKey > $1.dateKey }
        }
    }

    // MARK: - Lock helper

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Storage (Unlocked)

    private func loadDictUnlocked() -> ([String: Entry], hadError: Bool) {
        guard let data = defaults.data(forKey: storeKey) else { return ([:], false) }
        do {
            let dict = try JSONDecoder().decode([String: Entry].self, from: data)
            return (dict, false)
        } catch {
            #if DEBUG
            print("[AppGroupEntryRepository] decode failed:", error)
            #endif
            return ([:], true)
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
