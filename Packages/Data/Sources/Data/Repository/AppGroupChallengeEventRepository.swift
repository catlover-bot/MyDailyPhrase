import Foundation
import Domain

public final class AppGroupChallengeEventRepository: ChallengeEventRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.challengeEvents.v1"
    private let maxCount = 500

    private let lock = NSLock()

    public init(appGroupID: String) {
        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
            #if DEBUG
            print("[AppGroupChallengeEventRepository] using suiteName:", appGroupID)
            #endif
        } else {
            self.defaults = .standard
            #if DEBUG
            print("[AppGroupChallengeEventRepository] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
            #endif
        }
    }

    public func upsert(_ event: ChallengeEvent) {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            guard !hadError else {
                #if DEBUG
                print("[AppGroupChallengeEventRepository] decode failed previously; abort upsert to avoid wiping store.")
                #endif
                return
            }
            var newDict = dict
            newDict[event.id] = event
            saveDictUnlocked(prune(newDict))
        }
    }

    public func list(box: EventBox) -> [ChallengeEvent] {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return [] }
            return dict.values
                .filter { $0.box == box }
                .sorted { $0.storedAt > $1.storedAt }
        }
    }

    public func deleteAll() {
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

    private func loadDictUnlocked() -> ([String: ChallengeEvent], hadError: Bool) {
        guard let data = defaults.data(forKey: storeKey) else { return ([:], false) }
        do {
            let dict = try JSONDecoder().decode([String: ChallengeEvent].self, from: data)
            return (dict, false)
        } catch {
            #if DEBUG
            print("[AppGroupChallengeEventRepository] decode failed:", error)
            #endif
            return ([:], true)
        }
    }

    private func saveDictUnlocked(_ dict: [String: ChallengeEvent]) {
        do {
            let data = try JSONEncoder().encode(dict)
            defaults.set(data, forKey: storeKey)
        } catch {
            #if DEBUG
            print("[AppGroupChallengeEventRepository] encode failed:", error)
            #endif
        }
    }

    private func prune(_ dict: [String: ChallengeEvent]) -> [String: ChallengeEvent] {
        guard dict.count > maxCount else { return dict }
        let sorted = dict.values.sorted { $0.storedAt > $1.storedAt }
        let keep = sorted.prefix(maxCount)
        return Dictionary(uniqueKeysWithValues: keep.map { ($0.id, $0) })
    }
}
