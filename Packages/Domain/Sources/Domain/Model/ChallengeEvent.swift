import Foundation

public struct ChallengeEvent: Codable, Equatable, Sendable {
    public let id: String          // ChallengeLink.id
    public let box: EventBox       // inbox/outbox
    public let link: ChallengeLink
    public let storedAt: Date      // 端末に保存された時刻

    /// UI/ソート用の別名（storedAt と同義）
    public var createdAt: Date { storedAt }

    public init(id: String, box: EventBox, link: ChallengeLink, storedAt: Date = Date()) {
        self.id = id
        self.box = box
        self.link = link
        self.storedAt = storedAt
    }
}
