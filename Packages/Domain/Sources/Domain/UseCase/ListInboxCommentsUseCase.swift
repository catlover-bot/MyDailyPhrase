import Foundation

public struct ListInboxCommentsUseCase: Sendable {
    private let events: CommentEventRepository

    public init(events: CommentEventRepository) {
        self.events = events
    }

    public func callAsFunction() -> [CommentEvent] {
        events.list(box: .inbox).sorted { $0.createdAt > $1.createdAt }
    }
}
