import Foundation

public protocol RoomMembershipRepository: Sendable {
    func list() -> [RoomMembership]
    func upsert(_ membership: RoomMembership)
    func remove(roomId: String)
    func contains(roomId: String) -> Bool
}
