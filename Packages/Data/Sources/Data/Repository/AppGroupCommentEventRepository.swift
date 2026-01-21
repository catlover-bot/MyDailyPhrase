import Foundation
import Domain

public final class AppGroupCommentEventRepository: CommentEventRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.comments.v1"
    private let maxCount = 1000

    private let lock = NSLock()

    public init(appGroupID: String) {
        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
        } else {
            self.defaults = .standard
        }
    }

    public func upsert(_ event: CommentEvent) {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            guard !hadError else {
                #if DEBUG
                print("[AppGroupCommentEventRepository] decode failed previously; abort upsert to avoid wiping store.")
                #endif
                return
            }
            var newDict = dict
            newDict[event.id] = event
            saveDictUnlocked(prune(newDict))
        }
    }

    public func list(box: EventBox) -> [CommentEvent] {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return [] }
            return dict.values
                .filter { $0.box == box }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    // MARK: - Lock helper

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Storage (Unlocked)

    private func loadDictUnlocked() -> ([String: CommentEvent], hadError: Bool) {
        guard let data = defaults.data(forKey: storeKey) else { return ([:], false) }
        do {
            let dict = try JSONDecoder().decode([String: CommentEvent].self, from: data)
            return (dict, false)
        } catch {
            #if DEBUG
            print("[AppGroupCommentEventRepository] decode failed:", error)
            #endif
            return ([:], true)
        }
    }

    private func saveDictUnlocked(_ dict: [String: CommentEvent]) {
        do {
            let data = try JSONEncoder().encode(dict)
            defaults.set(data, forKey: storeKey)
        } catch {
            #if DEBUG
            print("[AppGroupCommentEventRepository] encode failed:", error)
            #endif
        }
    }

    private func prune(_ dict: [String: CommentEvent]) -> [String: CommentEvent] {
        guard dict.count > maxCount else { return dict }
        let sorted = dict.values.sorted { $0.createdAt > $1.createdAt }
        let keep = sorted.prefix(maxCount)
        return Dictionary(uniqueKeysWithValues: keep.map { ($0.id, $0) })
    }
}
