import Foundation

public protocol CommentEventRepository: Sendable {
    func upsert(_ event: CommentEvent)
    func list(box: EventBox) -> [CommentEvent]
}
