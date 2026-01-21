import Foundation

public struct LeaveRoomUseCase: Sendable {
    private let repo: RoomMembershipRepository

    public init(repo: RoomMembershipRepository) {
        self.repo = repo
    }

    public func callAsFunction(roomId: String) {
        repo.remove(roomId: roomId)
    }
}
