import Foundation
import Domain

public final class AppGroupUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.profile.v1"

    public init(appGroupID: String) {
        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
            print("[AppGroupUserProfileRepository] using suiteName:", appGroupID)
        } else {
            self.defaults = .standard
            print("[AppGroupUserProfileRepository] suiteName NOT found. fallback to .standard. appGroupID:", appGroupID)
        }
    }

    public func getMyProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: storeKey) else { return nil }
        do {
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("[AppGroupUserProfileRepository] decode failed:", error)
            return nil
        }
    }

    public func saveMyProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: storeKey)
        } catch {
            print("[AppGroupUserProfileRepository] encode failed:", error)
        }
    }
}
