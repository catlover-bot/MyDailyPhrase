import Foundation

public struct Prompt: Equatable, Sendable {
    public let id: Int
    public let text: String

    public init(id: Int, text: String) {
        self.id = id
        self.text = text
    }
}

public struct DailyEntry: Equatable, Sendable {
    public let dateKey: String
    public let prompt: Prompt
    public let answer: String?

    public init(dateKey: String, prompt: Prompt, answer: String?) {
        self.dateKey = dateKey
        self.prompt = prompt
        self.answer = answer
    }
}
