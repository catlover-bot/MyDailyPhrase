import Foundation

public struct CreateCommentLinkUseCase: Sendable {
    private let profileUC: GetMyProfileUseCase
    private let events: CommentEventRepository

    public init(profileUC: GetMyProfileUseCase, events: CommentEventRepository) {
        self.profileUC = profileUC
        self.events = events
    }

    public func callAsFunction(
        text: String,
        toChallengeId: String?,
        room: String?,
        chainId: String?
    ) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 長すぎると URL が重くなるので上限をかける（必要なら調整）
        let safeText = trimmed.count > 200 ? String(trimmed.prefix(200)) : trimmed

        let me = profileUC()
        let id = UUID().uuidString

        let link = CommentLink(
            id: id,
            text: safeText,
            toChallengeId: toChallengeId,
            room: room,
            chainId: chainId,
            fromId: me.userId,
            fromName: me.displayName
        )

        events.upsert(CommentEvent(id: id, box: .outbox, link: link, createdAt: Date()))
        return CommentLinkCodec.encode(link)
    }
}
