
import Foundation

public struct ListOutboxChallengesUseCase: Sendable {
    private let events: ChallengeEventRepository

    public init(events: ChallengeEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [ChallengeEvent] {
        events.list(box: .outbox).sorted { $0.storedAt > $1.storedAt }
    }
}
