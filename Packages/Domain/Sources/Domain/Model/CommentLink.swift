import Foundation

public struct CommentLink: Codable, Equatable, Sendable {
    public let v: Int
    public let id: String                 // commentId
    public let text: String
    public let toChallengeId: String?
    public let room: String?
    public let chainId: String?
    public let fromId: String
    public let fromName: String

    public init(
        v: Int = 1,
        id: String,
        text: String,
        toChallengeId: String? = nil,
        room: String? = nil,
        chainId: String? = nil,
        fromId: String,
        fromName: String
    ) {
        self.v = v
        self.id = id
        self.text = text
        self.toChallengeId = toChallengeId
        self.room = room
        self.chainId = chainId
        self.fromId = fromId
        self.fromName = fromName
    }
}
