import Foundation

public struct ListRoomsUseCase: Sendable {
    private let repo: RoomMembershipRepository

    public init(repo: RoomMembershipRepository) {
        self.repo = repo
    }

    public func callAsFunction() -> [RoomMembership] {
        repo.list()
    }
}
