import Foundation
import Domain

public final class AppGroupUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.profile.v1"

    // 同一プロセス内の read-modify-write を直列化
    private let queue = DispatchQueue(label: "MyDailyPhrase.UserProfileRepo")

    // エンコード/デコード（queue 内でのみ使用）
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // 拡張/Widget を入れる場合に true 推奨
    private let forceSynchronizeOnWrite: Bool

    public init(appGroupID: String, forceSynchronizeOnWrite: Bool = false) {
        self.forceSynchronizeOnWrite = forceSynchronizeOnWrite

        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
            print("[AppGroupUserProfileRepository] using suiteName:", appGroupID)
        } else {
            #if DEBUG
            preconditionFailure("AppGroup suiteName not found: \(appGroupID). Check entitlements for ALL targets.")
            #else
            self.defaults = .standard
            print("[AppGroupUserProfileRepository] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
            #endif
        }
    }

    // MARK: - Internal (queue only)

    private func _getMyProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: storeKey) else { return nil }
        do {
            return try decoder.decode(UserProfile.self, from: data)
        } catch {
            print("[AppGroupUserProfileRepository] decode failed:", error)
            return nil
        }
    }

    private func _saveMyProfile(_ profile: UserProfile) {
        var p = profile
        p.normalize() // ✅ 保存前に必ず整合性を担保

        do {
            let data = try encoder.encode(p)
            defaults.set(data, forKey: storeKey)
            if forceSynchronizeOnWrite {
                defaults.synchronize()
            }
        } catch {
            print("[AppGroupUserProfileRepository] encode failed:", error)
        }
    }

    // MARK: - UserProfileRepository

    public func getMyProfile() -> UserProfile? {
        queue.sync { _getMyProfile() }
    }

    public func saveMyProfile(_ profile: UserProfile) {
        queue.sync { _saveMyProfile(profile) }
    }

    @discardableResult
    public func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        queue.sync {
            var p = _getMyProfile() ?? makeIfMissing()
            mutate(&p)
            p.normalize() // ✅ mutate 後にも必ず normalize
            _saveMyProfile(p)
            return p
        }
    }
}
