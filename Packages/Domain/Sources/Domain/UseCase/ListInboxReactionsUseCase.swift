
import Foundation

public struct ListInboxReactionsUseCase: Sendable {
    private let events: ReactionEventRepository

    public init(events: ReactionEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [ReactionEvent] {
        events.list(box: .inbox).sorted { $0.storedAt > $1.storedAt }
    }
}
