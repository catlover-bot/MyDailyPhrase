
import Foundation

public struct ListOutboxReactionsUseCase: Sendable {
    private let events: ReactionEventRepository

    public init(events: ReactionEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [ReactionEvent] {
        events.list(box: .outbox).sorted { $0.storedAt > $1.storedAt }
    }
}
