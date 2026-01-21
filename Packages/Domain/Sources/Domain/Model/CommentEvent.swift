import Foundation

public struct CommentEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let box: EventBox
    public let link: CommentLink
    public let createdAt: Date

    public init(id: String, box: EventBox, link: CommentLink, createdAt: Date = Date()) {
        self.id = id
        self.box = box
        self.link = link
        self.createdAt = createdAt
    }
}
