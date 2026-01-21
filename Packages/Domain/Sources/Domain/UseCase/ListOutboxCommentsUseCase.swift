import Foundation

public struct ListOutboxCommentsUseCase: Sendable {
    private let events: CommentEventRepository

    public init(events: CommentEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [CommentEvent] {
        events.list(box: .outbox).sorted { $0.createdAt > $1.createdAt }
    }
}
