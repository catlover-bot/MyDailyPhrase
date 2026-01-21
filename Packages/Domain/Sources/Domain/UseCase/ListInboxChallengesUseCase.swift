
import Foundation

public struct ListInboxChallengesUseCase: Sendable {
    private let events: ChallengeEventRepository

    public init(events: ChallengeEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [ChallengeEvent] {
        events.list(box: .inbox).sorted { $0.storedAt > $1.storedAt }
    }
}
