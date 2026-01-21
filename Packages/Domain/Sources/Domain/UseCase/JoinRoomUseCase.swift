import Foundation

public struct JoinRoomUseCase: Sendable {
    private let repo: RoomMembershipRepository

    public init(repo: RoomMembershipRepository) {
        self.repo = repo
    }

    @discardableResult
    public func callAsFunction(roomId: String, roomName: String?) -> RoomMembership {
        let m = RoomMembership(roomId: roomId, roomName: roomName, joinedAt: Date())
        repo.upsert(m)
        return m
    }
}
