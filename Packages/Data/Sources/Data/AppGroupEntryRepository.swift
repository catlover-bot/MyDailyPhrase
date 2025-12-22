import Foundation
import Domain

public final class AppGroupEntryRepository: EntryRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let dictKey = "answers.v1" // 将来のマイグレーション用にバージョン付き

    public init(appGroupID: String) {
        guard let ud = UserDefaults(suiteName: appGroupID) else {
            fatalError("UserDefaults(suiteName:) failed. Check App Group ID: \(appGroupID)")
        }
        self.defaults = ud
    }

    public func loadAnswer(for dateKey: String) -> String? {
        let dict = defaults.dictionary(forKey: dictKey) as? [String: String]
        return dict?[dateKey]
    }

    public func saveAnswer(_ answer: String, for dateKey: String) {
        var dict = (defaults.dictionary(forKey: dictKey) as? [String: String]) ?? [:]
        dict[dateKey] = answer
        defaults.set(dict, forKey: dictKey)
    }

    public func allAnsweredDateKeys() -> Set<String> {
        let dict: [String: String] = (defaults.dictionary(forKey: dictKey) as? [String: String]) ?? [:]
        return Set(dict.keys)
    }
}
