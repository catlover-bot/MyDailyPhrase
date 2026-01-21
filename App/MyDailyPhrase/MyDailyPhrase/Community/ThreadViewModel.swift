import Foundation
import Combine
import Domain

@MainActor
final class ThreadViewModel: ObservableObject {

    struct CommentRow: Identifiable, Equatable {
        let id: String
        let text: String
        let fromName: String
        let isOutbox: Bool
    }

    struct ReactionCountRow: Identifiable, Equatable {
        let id: String   // emoji を id にする
        let emoji: String
        let count: Int
    }

    let challenge: ChallengeEvent

    @Published private(set) var commentRows: [CommentRow] = []
    @Published private(set) var reactionCounts: [ReactionCountRow] = []

    private let listInboxComments: ListInboxCommentsUseCase
    private let listOutboxComments: ListOutboxCommentsUseCase
    private let listInboxReactions: ListInboxReactionsUseCase

    private let createCommentLink: CreateCommentLinkUseCase
    private let createReactionLink: CreateReactionLinkUseCase

    init(
        challenge: ChallengeEvent,
        listInboxComments: ListInboxCommentsUseCase,
        listOutboxComments: ListOutboxCommentsUseCase,
        listInboxReactions: ListInboxReactionsUseCase,
        createCommentLink: CreateCommentLinkUseCase,
        createReactionLink: CreateReactionLinkUseCase
    ) {
        self.challenge = challenge
        self.listInboxComments = listInboxComments
        self.listOutboxComments = listOutboxComments
        self.listInboxReactions = listInboxReactions
        self.createCommentLink = createCommentLink
        self.createReactionLink = createReactionLink
    }

    func refresh() {
        let targetId = challenge.id

        // Comments: Inbox + Outbox をまとめて表示
        let inbox = listInboxComments().filter { $0.link.toChallengeId == targetId }
        let outbox = listOutboxComments().filter { $0.link.toChallengeId == targetId }

        // 送信/受信が混在しても見やすいように、まず inbox → outbox で連結（必要なら後で createdAt でソート）
        var rows: [CommentRow] = []
        rows.append(contentsOf: inbox.map {
            CommentRow(id: $0.id, text: $0.link.text, fromName: $0.link.fromName, isOutbox: false)
        })
        rows.append(contentsOf: outbox.map {
            CommentRow(id: $0.id, text: $0.link.text, fromName: $0.link.fromName, isOutbox: true)
        })
        self.commentRows = rows

        // Reactions: 現状は Inbox のみ一覧できる設計なので、Inbox から toChallengeId で集計
        let reactions = listInboxReactions().filter { $0.link.toChallengeId == targetId }
        var counts: [String: Int] = [:]
        for r in reactions {
            counts[r.link.emoji, default: 0] += 1
        }

        let sorted = counts
            .map { ReactionCountRow(id: $0.key, emoji: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.emoji < b.emoji
            }

        self.reactionCounts = sorted
    }

    func buildCommentURL(text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }

        return createCommentLink(
            text: t,
            toChallengeId: challenge.id,
            room: challenge.link.room,
            chainId: challenge.link.chainId
        )
    }

    func buildReactionURL(emoji: String) -> URL? {
        let e = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty { return nil }

        return createReactionLink(
            emoji: e,
            toChallengeId: challenge.id,
            room: challenge.link.room,
            chainId: challenge.link.chainId
        )
    }
}
