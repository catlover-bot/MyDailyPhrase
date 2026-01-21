import Foundation

public struct ChallengeLink: Codable, Equatable, Sendable {
    public static let maxPromptLength = 280

    public let v: Int
    public let id: String
    public let dateKey: String
    public let prompt: String
    public let fromId: String
    public let fromName: String
    public let room: String?
    public let chainId: String?
    public let createdAt: Date

    public init(
        v: Int = 1,
        id: String,
        dateKey: String,
        prompt: String,
        fromId: String,
        fromName: String,
        room: String?,
        chainId: String?,
        createdAt: Date = Date()
    ) {
        self.v = v
        self.id = id
        self.dateKey = dateKey
        self.prompt = String(prompt.prefix(Self.maxPromptLength))
        self.fromId = fromId
        self.fromName = fromName
        self.room = room
        self.chainId = chainId
        self.createdAt = createdAt
    }
}
