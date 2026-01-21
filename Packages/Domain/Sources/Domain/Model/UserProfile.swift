import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public let userId: String
    public var displayName: String

    public init(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName
    }
}
