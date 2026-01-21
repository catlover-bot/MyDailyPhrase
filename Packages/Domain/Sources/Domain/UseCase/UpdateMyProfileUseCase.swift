import Foundation

public struct UpdateMyProfileUseCase: Sendable {
    private let repo: UserProfileRepository

    public init(repo: UserProfileRepository) {
        self.repo = repo
    }

    public func callAsFunction(displayName: String) -> UserProfile {
        var p = repo.getMyProfile() ?? UserProfile(userId: UUID().uuidString, displayName: "Me")
        p.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        repo.saveMyProfile(p)
        return p
    }
}
