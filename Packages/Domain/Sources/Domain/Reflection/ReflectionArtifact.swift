
import Foundation

public struct ReflectionArtifact: Codable, Equatable, Sendable {
    public let title: String
    public let summary: String
    public let keywords: [String]
    public let moodTags: [String]

    public init(title: String, summary: String, keywords: [String], moodTags: [String]) {
        self.title = title
        self.summary = summary
        self.keywords = keywords
        self.moodTags = moodTags
    }
}
