import Foundation
import Domain

public final class AppGroupRoomMembershipRepository: RoomMembershipRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let storeKey = "MyDailyPhrase.rooms.v1"

    private let lock = NSLock()

    public init(appGroupID: String) {
        if let ud = UserDefaults(suiteName: appGroupID) {
            self.defaults = ud
        } else {
            self.defaults = .standard
        }
    }

    public func list() -> [RoomMembership] {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return [] }
            return dict.values.sorted { $0.joinedAt > $1.joinedAt }
        }
    }

    public func upsert(_ membership: RoomMembership) {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            guard !hadError else {
                #if DEBUG
                print("[AppGroupRoomMembershipRepository] decode failed previously; abort upsert to avoid wiping store.")
                #endif
                return
            }
            var newDict = dict
            newDict[membership.roomId] = membership
            saveDictUnlocked(newDict)
        }
    }

    public func remove(roomId: String) {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            guard !hadError else { return } // ここで上書きしない
            var newDict = dict
            newDict.removeValue(forKey: roomId)
            saveDictUnlocked(newDict)
        }
    }

    public func contains(roomId: String) -> Bool {
        withLock {
            let (dict, hadError) = loadDictUnlocked()
            if hadError { return false }
            return dict[roomId] != nil
        }
    }

    // MARK: - Lock helper

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Storage (Unlocked)

    private func loadDictUnlocked() -> ([String: RoomMembership], hadError: Bool) {
        guard let data = defaults.data(forKey: storeKey) else { return ([:], false) }
        do {
            let dict = try JSONDecoder().decode([String: RoomMembership].self, from: data)
            return (dict, false)
        } catch {
            #if DEBUG
            print("[AppGroupRoomMembershipRepository] decode failed:", error)
            #endif
            return ([:], true)
        }
    }

    private func saveDictUnlocked(_ dict: [String: RoomMembership]) {
        do {
            let data = try JSONEncoder().encode(dict)
            defaults.set(data, forKey: storeKey)
        } catch {
            #if DEBUG
            print("[AppGroupRoomMembershipRepository] encode failed:", error)
            #endif
        }
    }
}
