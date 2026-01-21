import Foundation

public struct CreateReactionLinkUseCase: Sendable {
    private let profileUC: GetMyProfileUseCase
    private let events: ReactionEventRepository
    private let makeId: @Sendable () -> String
    private let now: @Sendable () -> Date

    public init(
        profileUC: GetMyProfileUseCase,
        events: ReactionEventRepository,
        makeId: @escaping @Sendable () -> String = { UUID().uuidString },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.profileUC = profileUC
        self.events = events
        self.makeId = makeId
        self.now = now
    }

    /// react 用 deep link を生成し、Outbox に ReactionEvent を保存する
    public func callAsFunction(
        emoji: String,
        toChallengeId: String?,
        room: String? = nil,
        chainId: String? = nil
    ) -> URL? {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let me = profileUC()
        let link = ReactionLink(
            id: makeId(),
            emoji: trimmed,
            toChallengeId: toChallengeId,
            fromId: me.userId,
            fromName: me.displayName,
            room: room,
            chainId: chainId
        )
        guard let url = DeepLinkCodec.makeURL(link) else { return nil }

        // storedAt を明示（モデルの default Date() と同じだが、テスト容易性が上がる）
        events.upsert(ReactionEvent(id: link.id, box: .outbox, link: link, storedAt: now()))
        return url
    }
}
