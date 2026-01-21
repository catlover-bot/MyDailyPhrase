import Foundation

public struct ReceiveCommentLinkUseCase: Sendable {
    private let events: CommentEventRepository

    public init(events: CommentEventRepository) {
        self.events = events
    }

    @discardableResult
    public func callAsFunction(url: URL) throws -> CommentEvent {
        let link = try CommentLinkCodec.decode(url)
        let ev = CommentEvent(id: link.id, box: .inbox, link: link, createdAt: Date())
        events.upsert(ev)
        return ev
    }
}
