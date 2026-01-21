import Foundation

public struct RoomInviteLink: Codable, Equatable, Sendable {
    public let v: Int
    public let inviteId: String
    public let roomId: String
    public let roomName: String?
    public let fromId: String
    public let fromName: String

    public init(
        v: Int = 1,
        inviteId: String,
        roomId: String,
        roomName: String? = nil,
        fromId: String,
        fromName: String
    ) {
        self.v = v
        self.inviteId = inviteId
        self.roomId = roomId
        self.roomName = roomName
        self.fromId = fromId
        self.fromName = fromName
    }
}
