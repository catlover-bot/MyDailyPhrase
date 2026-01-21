import Foundation
import Domain
import Presentation
import Data

final class AppContainer {
    let appGroupID: String
    private let timeZone: TimeZone = .current

    // ===== Core =====
    private let entryRepo: EntryRepository
    private let promptRepo: PromptRepository

    private let enrichEntry: EnrichEntryUseCase
    private let toggleFavorite: ToggleFavoriteUseCase

    // ===== Profile / Challenge / Reaction =====
    private let profileRepo: UserProfileRepository
    private let challengeEventRepo: ChallengeEventRepository
    private let reactionEventRepo: ReactionEventRepository

    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase

    private let createChallengeLink: CreateChallengeLinkUseCase
    private let receiveChallengeLink: ReceiveChallengeLinkUseCase
    private let listInboxChallenges: ListInboxChallengesUseCase
    private let listOutboxChallenges: ListOutboxChallengesUseCase

    private let createReactionLink: CreateReactionLinkUseCase
    private let receiveReactionLink: ReceiveReactionLinkUseCase
    private let listInboxReactions: ListInboxReactionsUseCase
    private let listOutboxReactions: ListOutboxReactionsUseCase

    // ===== Room =====
    private let roomRepo: RoomMembershipRepository
    private let roomInviteRepo: RoomInviteEventRepository

    private let listRooms: ListRoomsUseCase
    private let joinRoom: JoinRoomUseCase
    private let leaveRoom: LeaveRoomUseCase

    private let createRoomInviteLink: CreateRoomInviteLinkUseCase
    private let receiveRoomInviteLink: ReceiveRoomInviteLinkUseCase
    private let listRoomInvites: ListRoomInvitesUseCase

    // ===== Comment =====
    private let commentEventRepo: CommentEventRepository
    private let createCommentLink: CreateCommentLinkUseCase
    private let receiveCommentLink: ReceiveCommentLinkUseCase
    private let listInboxComments: ListInboxCommentsUseCase
    private let listOutboxComments: ListOutboxCommentsUseCase

    // ===== Import Challenge → Entry =====
    private let importChallengeToEntry: ImportChallengeToEntryUseCase

    init(appGroupID: String = "group.MyDailyPhrase") {
        self.appGroupID = appGroupID

        // Core repos
        self.promptRepo = LocalPromptRepository()
        self.entryRepo = AppGroupEntryRepository(appGroupID: appGroupID)

        // Enrichment
        let service: TextEnrichmentService = HeuristicTextEnrichmentService()
        self.enrichEntry = EnrichEntryUseCase(service: service, locale: .current)
        self.toggleFavorite = ToggleFavoriteUseCase(entryRepo: entryRepo)

        // Profile / events repos
        self.profileRepo = AppGroupUserProfileRepository(appGroupID: appGroupID)
        self.challengeEventRepo = AppGroupChallengeEventRepository(appGroupID: appGroupID)
        self.reactionEventRepo = AppGroupReactionEventRepository(appGroupID: appGroupID)

        self.getMyProfile = GetMyProfileUseCase(repo: profileRepo)
        self.updateMyProfile = UpdateMyProfileUseCase(repo: profileRepo)

        self.createChallengeLink = CreateChallengeLinkUseCase(profileUC: getMyProfile, events: challengeEventRepo)
        self.receiveChallengeLink = ReceiveChallengeLinkUseCase(events: challengeEventRepo)
        self.listInboxChallenges = ListInboxChallengesUseCase(events: challengeEventRepo)
        self.listOutboxChallenges = ListOutboxChallengesUseCase(events: challengeEventRepo)

        self.createReactionLink = CreateReactionLinkUseCase(profileUC: getMyProfile, events: reactionEventRepo)
        self.receiveReactionLink = ReceiveReactionLinkUseCase(events: reactionEventRepo)
        self.listInboxReactions = ListInboxReactionsUseCase(events: reactionEventRepo)
        self.listOutboxReactions = ListOutboxReactionsUseCase(events: reactionEventRepo)

        // Room
        self.roomRepo = AppGroupRoomMembershipRepository(appGroupID: appGroupID)
        self.roomInviteRepo = AppGroupRoomInviteEventRepository(appGroupID: appGroupID)

        self.listRooms = ListRoomsUseCase(repo: roomRepo)
        self.joinRoom = JoinRoomUseCase(repo: roomRepo)
        self.leaveRoom = LeaveRoomUseCase(repo: roomRepo)

        self.createRoomInviteLink = CreateRoomInviteLinkUseCase(profileUC: getMyProfile, events: roomInviteRepo)
        self.receiveRoomInviteLink = ReceiveRoomInviteLinkUseCase(events: roomInviteRepo)
        self.listRoomInvites = ListRoomInvitesUseCase(events: roomInviteRepo)

        // Comment
        self.commentEventRepo = AppGroupCommentEventRepository(appGroupID: appGroupID)
        self.createCommentLink = CreateCommentLinkUseCase(profileUC: getMyProfile, events: commentEventRepo)
        self.receiveCommentLink = ReceiveCommentLinkUseCase(events: commentEventRepo)
        self.listInboxComments = ListInboxCommentsUseCase(events: commentEventRepo)
        self.listOutboxComments = ListOutboxCommentsUseCase(events: commentEventRepo)

        // Import Challenge → Entry
        self.importChallengeToEntry = ImportChallengeToEntryUseCase(entryRepo: entryRepo)
    }

    // MARK: - Deep link handling

    func handleIncomingDeepLink(_ url: URL) {
        // 1) Room
        if url.scheme == RoomLinkCodec.scheme, let host = url.host {
            do {
                switch host {
                case RoomLinkCodec.hostInvite:
                    _ = try receiveRoomInviteLink(url: url)
                    debugLog("[DeepLink] received room_invite:", url.absoluteString)
                    return

                case RoomLinkCodec.hostJoin:
                    let join = try RoomLinkCodec.decodeJoin(url)
                    _ = joinRoom(roomId: join.roomId, roomName: join.roomName)
                    debugLog("[DeepLink] received room_join:", url.absoluteString)
                    return

                default:
                    break
                }
            } catch {
                debugLog("[DeepLink] room failed:", error.localizedDescription)
                return
            }
        }

        // 2) Comment
        if url.scheme == CommentLinkCodec.scheme, url.host == CommentLinkCodec.hostComment {
            do {
                _ = try receiveCommentLink(url: url)
                debugLog("[DeepLink] received comment:", url.absoluteString)
            } catch {
                debugLog("[DeepLink] comment failed:", error.localizedDescription)
            }
            return
        }

        // 3) Challenge / Reaction
        do {
            switch try DeepLinkCodec.parse(url) {
            case .challenge:
                _ = try receiveChallengeLink(url: url)
                debugLog("[DeepLink] received challenge:", url.absoluteString)

            case .react:
                _ = try receiveReactionLink(url: url)
                debugLog("[DeepLink] received react:", url.absoluteString)
            }
        } catch {
            debugLog("[DeepLink] failed:", error.localizedDescription)
        }
    }

    // MARK: - Share URL builders

    func makeChallengeShareURL(dateKey: String, prompt: String, room: String? = nil, chainId: String? = nil) -> URL? {
        createChallengeLink(dateKey: dateKey, prompt: prompt, room: room, chainId: chainId)
    }

    func makeReactionShareURL(emoji: String, toChallengeId: String?, room: String? = nil, chainId: String? = nil) -> URL? {
        createReactionLink(emoji: emoji, toChallengeId: toChallengeId, room: room, chainId: chainId)
    }

    func makeRoomInviteURL(roomId: String, roomName: String?) -> URL? {
        createRoomInviteLink(roomId: roomId, roomName: roomName)
    }

    func makeRoomJoinURL(roomId: String, roomName: String?) -> URL? {
        let me = getMyProfile()
        let link = RoomJoinLink(roomId: roomId, roomName: roomName, userId: me.userId, name: me.displayName)
        return RoomLinkCodec.encodeJoin(link)
    }

    func makeCommentShareURL(text: String, toChallengeId: String?, room: String?, chainId: String?) -> URL? {
        createCommentLink(text: text, toChallengeId: toChallengeId, room: room, chainId: chainId)
    }

    // MARK: - Presentation VMs

    func makeHomeViewModel() -> Presentation.HomeViewModel {
        let getTodayEntry = GetTodayEntryUseCase(promptRepo: promptRepo, entryRepo: entryRepo, timeZone: timeZone)
        let saveTodayAnswer = SaveTodayAnswerUseCase(promptRepo: promptRepo, entryRepo: entryRepo, timeZone: timeZone)
        let computeStreak = ComputeStreakUseCase(entryRepo: entryRepo, timeZone: timeZone)
        let getEntryByOffset = GetEntryByOffsetUseCase(entryRepo: entryRepo, timeZone: timeZone)
        let getEntryByDateKey = GetEntryByDateKeyUseCase(promptRepo: promptRepo, entryRepo: entryRepo)
        let saveAnswerByDateKey = SaveAnswerByDateKeyUseCase(entryRepo: entryRepo)

        return Presentation.HomeViewModel(
            getTodayEntry: getTodayEntry,
            saveTodayAnswer: saveTodayAnswer,
            computeStreak: computeStreak,
            getEntryByOffset: getEntryByOffset,
            enrichEntry: enrichEntry,
            getEntryByDateKey: getEntryByDateKey,
            saveAnswerByDateKey: saveAnswerByDateKey
        )
    }

    func makeHistoryViewModel() -> Presentation.HistoryViewModel {
        let listEntries = ListEntriesUseCase(entryRepo: entryRepo)
        return Presentation.HistoryViewModel(listEntries: listEntries, toggleFavorite: toggleFavorite)
    }

    func makeReviewViewModel() -> Presentation.ReviewViewModel {
        let listEntries = ListEntriesUseCase(entryRepo: entryRepo)
        return Presentation.ReviewViewModel(listEntries: listEntries, enrichEntry: enrichEntry, timeZone: timeZone)
    }

    // MARK: - App VMs

    func makeCommunityViewModel() -> CommunityViewModel {
        return CommunityViewModel(
            listInboxChallenges: listInboxChallenges,
            listOutboxChallenges: listOutboxChallenges,
            listInboxReactions: listInboxReactions,
            listOutboxReactions: listOutboxReactions,

            listRooms: listRooms,
            joinRoom: joinRoom,
            leaveRoom: leaveRoom,
            listRoomInvites: listRoomInvites,
            makeRoomInviteURL: { [weak self] roomId, roomName in
                self?.makeRoomInviteURL(roomId: roomId, roomName: roomName)
            },
            makeRoomJoinURL: { [weak self] roomId, roomName in
                self?.makeRoomJoinURL(roomId: roomId, roomName: roomName)
            },

            createCommentLink: createCommentLink,
            listInboxComments: listInboxComments,
            listOutboxComments: listOutboxComments,

            makeReactionURL: { [weak self] emoji, toChallengeId, room, chainId in
                self?.makeReactionShareURL(emoji: emoji, toChallengeId: toChallengeId, room: room, chainId: chainId)
            },
            importChallengeToEntry: importChallengeToEntry
        )
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(get: getMyProfile, update: updateMyProfile)
    }

    // MARK: - Debug

    private func debugLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }
}
