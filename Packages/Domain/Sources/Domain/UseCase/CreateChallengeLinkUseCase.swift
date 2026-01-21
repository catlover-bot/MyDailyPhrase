import Foundation

public struct CreateChallengeLinkUseCase: Sendable {
    private let profileUC: GetMyProfileUseCase
    private let events: ChallengeEventRepository
    private let makeId: @Sendable () -> String
    private let now: @Sendable () -> Date

    public init(
        profileUC: GetMyProfileUseCase,
        events: ChallengeEventRepository,
        makeId: @escaping @Sendable () -> String = { UUID().uuidString },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.profileUC = profileUC
        self.events = events
        self.makeId = makeId
        self.now = now
    }

    /// share 用 deep link を生成し、Outbox に ChallengeEvent を保存する
    public func callAsFunction(
        dateKey: String,
        prompt: String,
        room: String? = nil,
        chainId: String? = nil
    ) -> URL? {
        let dk = dateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pr = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dk.isEmpty, !pr.isEmpty else { return nil }

        let me = profileUC()
        let link = ChallengeLink(
            id: makeId(),
            dateKey: dk,
            prompt: pr,
            fromId: me.userId,
            fromName: me.displayName,
            room: room,
            chainId: chainId
        )
        guard let url = DeepLinkCodec.makeURL(link) else { return nil }

        events.upsert(ChallengeEvent(id: link.id, box: .outbox, link: link, storedAt: now()))
        return url
    }
}
