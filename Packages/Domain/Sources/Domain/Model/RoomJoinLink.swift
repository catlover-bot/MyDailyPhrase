import Foundation

public struct RoomJoinLink: Codable, Equatable, Sendable {
    public let v: Int
    public let roomId: String
    public let roomName: String?
    public let userId: String
    public let name: String

    public init(v: Int = 1, roomId: String, roomName: String? = nil, userId: String, name: String) {
        self.v = v
        self.roomId = roomId
        self.roomName = roomName
        self.userId = userId
        self.name = name
    }
}
