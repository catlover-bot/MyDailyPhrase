import Foundation

public struct ReactionEvent: Codable, Equatable, Sendable {
    public let id: String          // ReactionLink.id
    public let box: EventBox
    public let link: ReactionLink
    public let storedAt: Date


    /// UI/ソート用の別名（storedAt と同義）
    public var createdAt: Date { storedAt }
    public init(id: String, box: EventBox, link: ReactionLink, storedAt: Date = Date()) {
        self.id = id
        self.box = box
        self.link = link
        self.storedAt = storedAt
    }
}
