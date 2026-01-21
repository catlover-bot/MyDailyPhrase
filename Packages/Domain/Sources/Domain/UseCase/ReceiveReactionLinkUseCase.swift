import Foundation

public struct ReceiveReactionLinkUseCase: Sendable {
    private let events: ReactionEventRepository
    private let now: @Sendable () -> Date

    public init(
        events: ReactionEventRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.events = events
        self.now = now
    }

    public func callAsFunction(url: URL) throws -> ReactionEvent {
        let parsed = try DeepLinkCodec.parse(url)
        guard case let .react(link) = parsed else {
            throw DeepLinkError.invalidHost(actual: URLComponents(url: url, resolvingAgainstBaseURL: false)?.host)
        }
        let ev = ReactionEvent(id: link.id, box: .inbox, link: link, storedAt: now())
        events.upsert(ev)
        return ev
    }
}
