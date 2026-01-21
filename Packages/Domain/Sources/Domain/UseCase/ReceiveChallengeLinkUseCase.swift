import Foundation

public struct ReceiveChallengeLinkUseCase: Sendable {
    private let events: ChallengeEventRepository
    private let now: @Sendable () -> Date

    public init(
        events: ChallengeEventRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.events = events
        self.now = now
    }

    /// 受信したURLを解析して Inbox に保存する
    public func callAsFunction(url: URL) throws -> ChallengeEvent {
        let parsed = try DeepLinkCodec.parse(url)
        guard case let .challenge(link) = parsed else {
            throw DeepLinkError.invalidHost(actual: URLComponents(url: url, resolvingAgainstBaseURL: false)?.host)
        }
        let ev = ChallengeEvent(id: link.id, box: .inbox, link: link, storedAt: now())
        events.upsert(ev)
        return ev
    }
}
