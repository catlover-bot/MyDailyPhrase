import Foundation

public protocol PromptRepository: Sendable {
    func prompt(for date: Date) -> Prompt
}

public protocol EntryRepository: Sendable {
    func loadAnswer(for dateKey: String) -> String?
    func saveAnswer(_ answer: String, for dateKey: String)
    func allAnsweredDateKeys() -> Set<String>
}
