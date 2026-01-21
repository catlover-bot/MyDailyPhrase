import Foundation

public protocol ReactionEventRepository: Sendable {
    func upsert(_ event: ReactionEvent)
    func list(box: EventBox) -> [ReactionEvent]
    func deleteAll()
}
