import Foundation
import Combine
import Domain

@MainActor
final class CommunityViewModel: ObservableObject {
    // MARK: - Filter
    @Published var roomFilter: String = ""   // roomId を想定（空で全件）

    // MARK: - Challenges
    @Published private(set) var inboxChallenges: [ChallengeEvent] = []
    @Published private(set) var outboxChallenges: [ChallengeEvent] = []

    // MARK: - Reactions
    @Published private(set) var inboxReactions: [ReactionEvent] = []
    @Published private(set) var outboxReactions: [ReactionEvent] = []

    // MARK: - Room
    @Published private(set) var rooms: [RoomMembership] = []
    @Published private(set) var inboxRoomInvites: [RoomInviteEvent] = []
    @Published private(set) var outboxRoomInvites: [RoomInviteEvent] = []
    @Published var inviteRoomId: String = ""
    @Published var inviteRoomName: String = ""

    // MARK: - Comment
    @Published private(set) var inboxComments: [CommentEvent] = []
    @Published private(set) var outboxComments: [CommentEvent] = []

    // MARK: - Room Timeline（統合フィード）
    @Published private(set) var roomTimeline: [RoomFeedItem] = []

    // MARK: - UseCases
    private let listInboxChallenges: ListInboxChallengesUseCase
    private let listOutboxChallenges: ListOutboxChallengesUseCase
    private let listInboxReactions: ListInboxReactionsUseCase
    private let listOutboxReactions: ListOutboxReactionsUseCase

    private let listRooms: ListRoomsUseCase
    private let joinRoom: JoinRoomUseCase
    private let leaveRoom: LeaveRoomUseCase
    private let listRoomInvites: ListRoomInvitesUseCase
    private let makeRoomInviteURL: (String, String?) -> URL?
    private let makeRoomJoinURL: (String, String?) -> URL?

    private let createCommentLink: CreateCommentLinkUseCase
    private let listInboxComments: ListInboxCommentsUseCase
    private let listOutboxComments: ListOutboxCommentsUseCase

    /// Reactionリンク生成（Threadから送る用途）
    private let makeReactionURL: (String, String?, String?, String?) -> URL?

    /// Challenge取り込み
    private let importChallengeToEntry: ImportChallengeToEntryUseCase

    // MARK: - Init
    init(
        listInboxChallenges: ListInboxChallengesUseCase,
        listOutboxChallenges: ListOutboxChallengesUseCase,
        listInboxReactions: ListInboxReactionsUseCase,
        listOutboxReactions: ListOutboxReactionsUseCase,
        listRooms: ListRoomsUseCase,
        joinRoom: JoinRoomUseCase,
        leaveRoom: LeaveRoomUseCase,
        listRoomInvites: ListRoomInvitesUseCase,
        makeRoomInviteURL: @escaping (String, String?) -> URL?,
        makeRoomJoinURL: @escaping (String, String?) -> URL?,
        createCommentLink: CreateCommentLinkUseCase,
        listInboxComments: ListInboxCommentsUseCase,
        listOutboxComments: ListOutboxCommentsUseCase,
        makeReactionURL: @escaping (String, String?, String?, String?) -> URL?,
        importChallengeToEntry: ImportChallengeToEntryUseCase
    ) {
        self.listInboxChallenges = listInboxChallenges
        self.listOutboxChallenges = listOutboxChallenges
        self.listInboxReactions = listInboxReactions
        self.listOutboxReactions = listOutboxReactions

        self.listRooms = listRooms
        self.joinRoom = joinRoom
        self.leaveRoom = leaveRoom
        self.listRoomInvites = listRoomInvites
        self.makeRoomInviteURL = makeRoomInviteURL
        self.makeRoomJoinURL = makeRoomJoinURL

        self.createCommentLink = createCommentLink
        self.listInboxComments = listInboxComments
        self.listOutboxComments = listOutboxComments

        self.makeReactionURL = makeReactionURL
        self.importChallengeToEntry = importChallengeToEntry
    }

    // MARK: - Refresh

    func refresh() {
        let f = roomFilter.trimmingCharacters(in: .whitespacesAndNewlines)

        func matchRoom(_ room: String?) -> Bool {
            if f.isEmpty { return true }
            return room == f
        }

        // fetch
        inboxChallenges = listInboxChallenges().filter { matchRoom($0.link.room) }
        outboxChallenges = listOutboxChallenges().filter { matchRoom($0.link.room) }

        inboxReactions = listInboxReactions().filter { matchRoom($0.link.room) }
        outboxReactions = listOutboxReactions().filter { matchRoom($0.link.room) }

        inboxComments = listInboxComments().filter { matchRoom($0.link.room) }
        outboxComments = listOutboxComments().filter { matchRoom($0.link.room) }

        rooms = listRooms()

        // invites: roomFilter は roomId を想定
        inboxRoomInvites = listRoomInvites(box: .inbox).filter { f.isEmpty ? true : $0.link.roomId == f }
        outboxRoomInvites = listRoomInvites(box: .outbox).filter { f.isEmpty ? true : $0.link.roomId == f }

        // sort（新しい順）
        inboxChallenges.sort { $0.createdAt > $1.createdAt }
        outboxChallenges.sort { $0.createdAt > $1.createdAt }
        inboxReactions.sort { $0.createdAt > $1.createdAt }
        outboxReactions.sort { $0.createdAt > $1.createdAt }

        inboxComments.sort { $0.createdAt > $1.createdAt }
        outboxComments.sort { $0.createdAt > $1.createdAt }
        inboxRoomInvites.sort { $0.createdAt > $1.createdAt }
        outboxRoomInvites.sort { $0.createdAt > $1.createdAt }

        rebuildRoomTimeline()
    }

    // MARK: - Room

    func joinFromInvite(_ invite: RoomInviteEvent) {
        _ = joinRoom(roomId: invite.link.roomId, roomName: invite.link.roomName)
        roomFilter = invite.link.roomId
        refresh()
    }

    func leave(roomId: String) {
        leaveRoom(roomId: roomId)
        if roomFilter == roomId { roomFilter = "" }
        refresh()
    }

    func buildInviteURL() -> URL? {
        let rid = inviteRoomId.trimmingCharacters(in: .whitespacesAndNewlines)
        if rid.isEmpty { return nil }
        let name = inviteRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
        return makeRoomInviteURL(rid, name.isEmpty ? nil : name)
    }

    func buildJoinURL(roomId: String, roomName: String?) -> URL? {
        makeRoomJoinURL(roomId, roomName)
    }

    // MARK: - Comment / Reaction URL

    func buildCommentURL(text: String, toChallengeId: String?, room: String?, chainId: String?) -> URL? {
        createCommentLink(text: text, toChallengeId: toChallengeId, room: room, chainId: chainId)
    }

    func buildReactionURL(emoji: String, toChallengeId: String?, room: String?, chainId: String?) -> URL? {
        makeReactionURL(emoji, toChallengeId, room, chainId)
    }

    // MARK: - Thread helpers

    func commentCount(for challengeId: String) -> Int {
        (inboxComments + outboxComments).filter { $0.link.toChallengeId == challengeId }.count
    }

    func reactionCount(for challengeId: String) -> Int {
        (inboxReactions + outboxReactions).filter { $0.link.toChallengeId == challengeId }.count
    }

    /// Thread（コメント＋リアクション）を createdAt 昇順で返す（読みやすい）
    func threadItems(for challenge: ChallengeEvent) -> [ThreadItem] {
        let cid = challenge.id

        let comments = (inboxComments + outboxComments)
            .filter { $0.link.toChallengeId == cid }
            .map { ThreadItem.comment($0, isMine: $0.box == .outbox) }

        let reactions = (inboxReactions + outboxReactions)
            .filter { $0.link.toChallengeId == cid }
            .map { ThreadItem.reaction($0, isMine: $0.box == .outbox) }

        return (comments + reactions).sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Import challenge to diary

    func importToDiary(_ challenge: ChallengeEvent) {
        _ = importChallengeToEntry.execute(challenge: challenge)
    }

    // MARK: - Room timeline

    private func rebuildRoomTimeline() {
        let f = roomFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty else {
            roomTimeline = []
            return
        }

        var items: [RoomFeedItem] = []

        for ev in (inboxChallenges + outboxChallenges) where ev.link.room == f {
            items.append(.init(
                id: "ch-\(ev.id)",
                createdAt: ev.createdAt,
                kind: .challenge,
                title: ev.link.prompt,
                subtitle: ev.box == .outbox ? "Challenge（送信）" : "Challenge from \(ev.link.fromName)",
                room: ev.link.room,
                chainId: ev.link.chainId,
                relatedChallengeId: ev.id
            ))
        }

        for ev in (inboxComments + outboxComments) where ev.link.room == f {
            items.append(.init(
                id: "cm-\(ev.id)",
                createdAt: ev.createdAt,
                kind: .comment,
                title: ev.link.text,
                subtitle: ev.box == .outbox ? "Comment（送信）" : "Comment from \(ev.link.fromName)",
                room: ev.link.room,
                chainId: ev.link.chainId,
                relatedChallengeId: ev.link.toChallengeId
            ))
        }

        for ev in (inboxReactions + outboxReactions) where ev.link.room == f {
            items.append(.init(
                id: "re-\(ev.id)",
                createdAt: ev.createdAt,
                kind: .reaction,
                title: ev.link.emoji,
                subtitle: ev.box == .outbox ? "Reaction（送信）" : "Reaction from \(ev.link.fromName)",
                room: ev.link.room,
                chainId: ev.link.chainId,
                relatedChallengeId: ev.link.toChallengeId
            ))
        }

        roomTimeline = items.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Thread item / Room feed item

extension CommunityViewModel {
    enum ThreadItem: Identifiable {
        case comment(CommentEvent, isMine: Bool)
        case reaction(ReactionEvent, isMine: Bool)

        var id: String {
            switch self {
            case .comment(let ev, _): return "c-\(ev.id)"
            case .reaction(let ev, _): return "r-\(ev.id)"
            }
        }

        var createdAt: Date {
            switch self {
            case .comment(let ev, _): return ev.createdAt
            case .reaction(let ev, _): return ev.createdAt
            }
        }
    }

    struct RoomFeedItem: Identifiable {
        enum Kind { case challenge, comment, reaction }
        let id: String
        let createdAt: Date
        let kind: Kind
        let title: String
        let subtitle: String
        let room: String?
        let chainId: String?
        let relatedChallengeId: String?
    }
}
