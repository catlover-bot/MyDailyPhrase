import Foundation
import Domain

public final class AppGroupUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.profile.v1"
    private let backupStoreKey = "MyDailyPhrase.profile.backup.v1"
    private let corruptStoreKey = "MyDailyPhrase.profile.corrupt.v1"
    private let recoveryMarkerKey = "MyDailyPhrase.profile.recoveredAt.v1"

    // read-modify-write を直列化。再入時の自己デッドロックを避けるため recursive lock を使う。
    private let lock = NSRecursiveLock()

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
            self.defaults = .standard
            print("[AppGroupUserProfileRepository] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
            assertionFailure("AppGroup suiteName not found: \(appGroupID). Fallback to .standard.")
        }
    }

    // MARK: - Internal (queue only)

    private func decodeProfile(_ data: Data, sourceKey: String) -> UserProfile? {
        do {
            return try decoder.decode(UserProfile.self, from: data)
        } catch {
            print("[AppGroupUserProfileRepository] decode failed:", sourceKey, error)
            return nil
        }
    }

    private func _getMyProfile() -> UserProfile? {
        if let primaryData = defaults.data(forKey: storeKey) {
            if let profile = decodeProfile(primaryData, sourceKey: storeKey) {
                return profile
            }
            defaults.set(primaryData, forKey: corruptStoreKey)
        }

        guard let backupData = defaults.data(forKey: backupStoreKey),
              let recovered = decodeProfile(backupData, sourceKey: backupStoreKey) else {
            return nil
        }

        defaults.set(backupData, forKey: storeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: recoveryMarkerKey)
        if forceSynchronizeOnWrite {
            defaults.synchronize()
        }
        print("[AppGroupUserProfileRepository] recovered profile from backup")
        return recovered
    }

    private func _saveMyProfile(_ profile: UserProfile) {
        var p = profile
        p.normalize() // ✅ 保存前に必ず整合性を担保

        do {
            let data = try encoder.encode(p)
            defaults.set(data, forKey: storeKey)
            defaults.set(data, forKey: backupStoreKey)
            defaults.removeObject(forKey: corruptStoreKey)
            if forceSynchronizeOnWrite {
                defaults.synchronize()
            }
        } catch {
            print("[AppGroupUserProfileRepository] encode failed:", error)
        }
    }

    // MARK: - UserProfileRepository

    public func getMyProfile() -> UserProfile? {
        withLock { _getMyProfile() }
    }

    public func saveMyProfile(_ profile: UserProfile) {
        withLock { _saveMyProfile(profile) }
    }

    @discardableResult
    public func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        withLock {
            var p = _getMyProfile() ?? makeIfMissing()
            mutate(&p)
            p.normalize() // ✅ mutate 後にも必ず normalize
            _saveMyProfile(p)
            return p
        }
    }

    @inline(__always)
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
