import Foundation

public protocol PromptRepository: Sendable {
    func prompt(for dateKey: String) -> Prompt
}
