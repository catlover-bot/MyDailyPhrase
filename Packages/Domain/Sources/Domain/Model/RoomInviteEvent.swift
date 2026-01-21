import Foundation

public struct RoomInviteEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let box: EventBox
    public let link: RoomInviteLink
    public let createdAt: Date

    public init(id: String, box: EventBox, link: RoomInviteLink, createdAt: Date = Date()) {
        self.id = id
        self.box = box
        self.link = link
        self.createdAt = createdAt
    }
}
