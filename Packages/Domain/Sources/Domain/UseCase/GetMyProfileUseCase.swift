import Foundation

public struct GetMyProfileUseCase: Sendable {
    private let repo: UserProfileRepository

    public init(repo: UserProfileRepository) {
        self.repo = repo
    }

    public func callAsFunction() -> UserProfile {
        if let p = repo.getMyProfile() { return p }
        let p = UserProfile(userId: UUID().uuidString, displayName: "Me")
        repo.saveMyProfile(p)
        return p
    }
}
