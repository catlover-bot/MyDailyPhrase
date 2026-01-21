import Foundation

public struct ReactionLink: Codable, Equatable, Sendable {
    public let v: Int
    public let id: String
    public let emoji: String
    public let toChallengeId: String?
    public let fromId: String
    public let fromName: String
    public let room: String?
    public let chainId: String?
    public let createdAt: Date

    public init(
        v: Int = 1,
        id: String,
        emoji: String,
        toChallengeId: String?,
        fromId: String,
        fromName: String,
        room: String?,
        chainId: String?,
        createdAt: Date = Date()
    ) {
        self.v = v
        self.id = id
        self.emoji = emoji
        self.toChallengeId = toChallengeId
        self.fromId = fromId
        self.fromName = fromName
        self.room = room
        self.chainId = chainId
        self.createdAt = createdAt
    }
}
