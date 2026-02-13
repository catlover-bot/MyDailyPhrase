import Foundation

public protocol UserProfileRepository: Sendable {
    func getMyProfile() -> UserProfile?
    func saveMyProfile(_ profile: UserProfile)

    /// read-modify-write を原子的に（同一プロセス内で）直列化して実行するための API。
    /// - Important: 実装側で排他（例: serial queue）を担保すること。
    @discardableResult
    func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile
}
