import Foundation

public struct RoomMembership: Codable, Equatable, Sendable, Identifiable {
    public var id: String { roomId }
    public let roomId: String
    public var roomName: String?
    public let joinedAt: Date

    public init(roomId: String, roomName: String? = nil, joinedAt: Date = Date()) {
        self.roomId = roomId
        self.roomName = roomName
        self.joinedAt = joinedAt
    }
}
