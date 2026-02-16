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
    @Published private(set) var profileDisplayName: String = "Me"
    @Published private(set) var profileUserId: String = "-"
    @Published private(set) var profileShortUserId: String = "-"
    @Published private(set) var profileSeasonBadgeText: String? = nil
    @Published private(set) var profileSeasonBadgeLevel: Int = 0
    @Published private(set) var referralCode: String = "MDP-GUEST"
    @Published private(set) var referralInviteURL: URL? = nil
    @Published private(set) var pulse: CommunityPulse = .empty
    @Published var weeklyRankingMetric: WeeklyRankingMetric = .streak {
        didSet { sortWeeklyRanking() }
    }
    @Published private(set) var weeklyRankingWindowText: String = ""
    @Published private(set) var weeklyRanking: [WeeklyRankingEntry] = []
    @Published private(set) var weeklyTrends: [WeeklyTrend] = []
    @Published private(set) var trendChallengeIndex: [String: [TrendChallengeItem]] = [:]
    @Published private(set) var myWeeklyRank: Int? = nil
    @Published private(set) var myWeeklyEntry: WeeklyRankingEntry? = nil
    @Published private(set) var weeklyRivalAbove: WeeklyRankingEntry? = nil
    @Published private(set) var weeklyRivalBelow: WeeklyRankingEntry? = nil
    @Published private(set) var weeklyMission: WeeklyMissionStatus = .empty
    @Published private(set) var roomSummaries: [RoomActivitySummary] = []
    @Published private(set) var activeMembers: [MemberSummary] = []
    @Published private(set) var lastRefreshedAt: Date? = nil
    @Published private(set) var mutedUsers: [MutedUser] = []
    @Published private(set) var blockedUsers: [BlockedUser] = []
    @Published private(set) var safetyReports: [SafetyReport] = []
    @Published private(set) var unreadInboxCount: Int = 0

    // MARK: - UseCases
    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
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
    private let makeChallengeShareURL: (String, String) -> URL?

    private let createCommentLink: CreateCommentLinkUseCase
    private let listInboxComments: ListInboxCommentsUseCase
    private let listOutboxComments: ListOutboxCommentsUseCase

    /// Reactionリンク生成（Threadから送る用途）
    private let makeReactionURL: (String, String?, String?, String?) -> URL?

    /// Challenge取り込み
    private let importChallengeToEntry: ImportChallengeToEntryUseCase
    private let isCreatorPassActiveProvider: @Sendable () -> Bool
    private let defaults: UserDefaults
    private let mutedUsersKey = "MyDailyPhrase.community.mutedUsers.v1"
    private let blockedUsersKey = "MyDailyPhrase.community.blockedUsers.v1"
    private let safetyReportsKey = "MyDailyPhrase.community.safetyReports.v1"
    private let lastInboxSeenAtKey = "MyDailyPhrase.community.lastInboxSeenAt.v1"
    private let weeklyMissionClaimedWeekKey = "MyDailyPhrase.community.weeklyMission.claimedWeek.v1"
    private let weeklyMissionClaimedTierKey = "MyDailyPhrase.community.weeklyMission.claimedTier.v1"
    private let weeklyMissionClaimedDecorationKey = "MyDailyPhrase.community.weeklyMission.claimedDecoration.v1"
    private let weeklyMissionBaseRewardTickets = 4
    private let weeklyMissionCreatorPassBonusTickets = 3
    private let weeklyMissionRankingTop3BonusTickets = 6
    private let weeklyMissionRankingTop10BonusTickets = 4
    private let weeklyMissionRankingTop30BonusTickets = 2
    private let safetyReportLimit = 50
    private let reportDedupWindowSeconds: TimeInterval = 60
    private var lastInboxSeenAt: Date?
    private var latestInboxEventAt: Date?

    // MARK: - Init
    init(
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase,
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
        makeChallengeShareURL: @escaping (String, String) -> URL?,
        createCommentLink: CreateCommentLinkUseCase,
        listInboxComments: ListInboxCommentsUseCase,
        listOutboxComments: ListOutboxCommentsUseCase,
        makeReactionURL: @escaping (String, String?, String?, String?) -> URL?,
        importChallengeToEntry: ImportChallengeToEntryUseCase,
        isCreatorPassActiveProvider: @escaping @Sendable () -> Bool = { false },
        defaults: UserDefaults = .standard
    ) {
        self.getMyProfile = getMyProfile
        self.updateMyProfile = updateMyProfile
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
        self.makeChallengeShareURL = makeChallengeShareURL

        self.createCommentLink = createCommentLink
        self.listInboxComments = listInboxComments
        self.listOutboxComments = listOutboxComments

        self.makeReactionURL = makeReactionURL
        self.importChallengeToEntry = importChallengeToEntry
        self.isCreatorPassActiveProvider = isCreatorPassActiveProvider
        self.defaults = defaults

        if let d = defaults.object(forKey: lastInboxSeenAtKey) as? Date {
            self.lastInboxSeenAt = d
        } else {
            self.lastInboxSeenAt = nil
        }

        if let data = defaults.data(forKey: mutedUsersKey),
           let decoded = try? JSONDecoder().decode([MutedUser].self, from: data) {
            self.mutedUsers = decoded.sorted { lhs, rhs in
                if lhs.mutedAt != rhs.mutedAt { return lhs.mutedAt > rhs.mutedAt }
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
        } else {
            self.mutedUsers = []
        }

        if let data = defaults.data(forKey: blockedUsersKey),
           let decoded = try? JSONDecoder().decode([BlockedUser].self, from: data) {
            self.blockedUsers = decoded.sorted { lhs, rhs in
                if lhs.blockedAt != rhs.blockedAt { return lhs.blockedAt > rhs.blockedAt }
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
        } else {
            self.blockedUsers = []
        }

        if let data = defaults.data(forKey: safetyReportsKey),
           let decoded = try? JSONDecoder().decode([SafetyReport].self, from: data) {
            self.safetyReports = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            self.safetyReports = []
        }
    }

    // MARK: - Refresh

    func refresh() {
        let f = roomFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        let me = getMyProfile()

        profileDisplayName = me.displayName
        profileUserId = me.userId
        profileShortUserId = me.userId.isEmpty ? "-" : String(me.userId.suffix(8))
        let seasonLimitedOwnedCount = me.ownedDecorationCounts.reduce(into: 0) { partialResult, pair in
            if pair.value > 0, CardDecorationCatalog.isSeasonLimited(pair.key) {
                partialResult += 1
            }
        }
        let badge = Self.seasonCollectorBadge(for: seasonLimitedOwnedCount)
        profileSeasonBadgeText = badge?.text
        profileSeasonBadgeLevel = badge?.level ?? 0
        referralCode = ReferralProgram.referralCode(for: me.userId)
        referralInviteURL = ReferralProgram.inviteURL(
            inviterId: me.userId,
            inviterName: me.displayName,
            code: referralCode
        )

        func matchRoom(_ room: String?) -> Bool {
            if f.isEmpty { return true }
            return room == f
        }

        let allInboxChallengesRaw = listInboxChallenges()
        let allOutboxChallenges = listOutboxChallenges()
        let allInboxReactionsRaw = listInboxReactions()
        let allOutboxReactions = listOutboxReactions()
        let allInboxCommentsRaw = listInboxComments()
        let allOutboxComments = listOutboxComments()
        let allRooms = listRooms()
        let allInboxInvitesRaw = listRoomInvites(box: .inbox)
        let allOutboxInvites = listRoomInvites(box: .outbox)

        let allInboxChallenges = allInboxChallengesRaw.filter { shouldShowInbound(userId: $0.link.fromId, displayName: $0.link.fromName) }
        let allInboxReactions = allInboxReactionsRaw.filter { shouldShowInbound(userId: $0.link.fromId, displayName: $0.link.fromName) }
        let allInboxComments = allInboxCommentsRaw.filter { shouldShowInbound(userId: $0.link.fromId, displayName: $0.link.fromName) }
        let allInboxInvites = allInboxInvitesRaw.filter { shouldShowInbound(userId: $0.link.fromId, displayName: $0.link.fromName) }

        updateUnreadCount(
            inboxChallenges: allInboxChallenges,
            inboxComments: allInboxComments,
            inboxReactions: allInboxReactions,
            inboxInvites: allInboxInvites
        )
        rebuildWeeklyRanking(
            myUserId: me.userId,
            mySeasonBadge: badge,
            inboxChallenges: allInboxChallenges,
            outboxChallenges: allOutboxChallenges,
            inboxComments: allInboxComments,
            outboxComments: allOutboxComments,
            inboxReactions: allInboxReactions,
            outboxReactions: allOutboxReactions,
            inboxInvites: allInboxInvites,
            outboxInvites: allOutboxInvites
        )
        rebuildWeeklyMission()
        let previousTopTrend = weeklyTrends.first
        rebuildWeeklyTrends(
            inboxChallenges: allInboxChallenges,
            outboxChallenges: allOutboxChallenges,
            inboxComments: allInboxComments,
            outboxComments: allOutboxComments,
            inboxReactions: allInboxReactions,
            outboxReactions: allOutboxReactions
        )
        publishWeeklyTrendUpdateIfNeeded(
            previousTopTrend: previousTopTrend,
            currentTopTrend: weeklyTrends.first
        )

        // fetch（フィルタ適用）
        inboxChallenges = allInboxChallenges.filter { matchRoom($0.link.room) }
        outboxChallenges = allOutboxChallenges.filter { matchRoom($0.link.room) }

        inboxReactions = allInboxReactions.filter { matchRoom($0.link.room) }
        outboxReactions = allOutboxReactions.filter { matchRoom($0.link.room) }

        inboxComments = allInboxComments.filter { matchRoom($0.link.room) }
        outboxComments = allOutboxComments.filter { matchRoom($0.link.room) }

        rooms = allRooms

        // invites: roomFilter は roomId を想定
        inboxRoomInvites = allInboxInvites.filter { f.isEmpty ? true : $0.link.roomId == f }
        outboxRoomInvites = allOutboxInvites.filter { f.isEmpty ? true : $0.link.roomId == f }

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
        rebuildInsights(myUserId: me.userId)
        lastRefreshedAt = Date()
    }

    // MARK: - Room

    func joinFromInvite(_ invite: RoomInviteEvent) {
        _ = joinRoom(roomId: invite.link.roomId, roomName: invite.link.roomName)
        appendCommunityAudit(
            kind: .communityRoomJoined,
            title: "ルーム参加",
            detail: "roomId=\(invite.link.roomId) roomName=\(invite.link.roomName ?? "-")"
        )
        roomFilter = invite.link.roomId
        refresh()
    }

    func leave(roomId: String) {
        leaveRoom(roomId: roomId)
        appendCommunityAudit(
            kind: .communityRoomLeft,
            title: "ルーム退出",
            detail: "roomId=\(roomId)"
        )
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

    func canModerateTarget(userId: String, displayName: String) -> Bool {
        !isSelfTarget(userId: userId, displayName: displayName)
    }

    func mute(userId: String, displayName: String) {
        guard canModerateTarget(userId: userId, displayName: displayName) else { return }

        let id = makeModerationID(userId: userId, displayName: displayName)
        guard !id.isEmpty else { return }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.isEmpty ? "Unknown" : name
        let now = Date()

        if let idx = mutedUsers.firstIndex(where: { $0.id == id }) {
            mutedUsers[idx] = MutedUser(
                id: id,
                userId: userId.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: normalizedName,
                mutedAt: now
            )
        } else {
            mutedUsers.append(
                MutedUser(
                    id: id,
                    userId: userId.trimmingCharacters(in: .whitespacesAndNewlines),
                    displayName: normalizedName,
                    mutedAt: now
                )
            )
        }

        mutedUsers.sort { lhs, rhs in
            if lhs.mutedAt != rhs.mutedAt { return lhs.mutedAt > rhs.mutedAt }
            return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
        }
        persistMutedUsers()
        appendCommunityAudit(
            kind: .communityUserMuted,
            title: "ユーザーミュート",
            detail: "target=\(normalizedName) id=\(id)"
        )
        refresh()
    }

    func unmute(id: String) {
        let target = mutedUsers.first(where: { $0.id == id })
        mutedUsers.removeAll { $0.id == id }
        persistMutedUsers()
        appendCommunityAudit(
            kind: .communityUserUnmuted,
            title: "ミュート解除",
            detail: "target=\(target?.displayName ?? "-") id=\(id)"
        )
        refresh()
    }

    func block(userId: String, displayName: String) {
        guard canModerateTarget(userId: userId, displayName: displayName) else { return }

        let id = makeModerationID(userId: userId, displayName: displayName)
        guard !id.isEmpty else { return }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.isEmpty ? "Unknown" : name
        let now = Date()

        if let idx = blockedUsers.firstIndex(where: { $0.id == id }) {
            blockedUsers[idx] = BlockedUser(
                id: id,
                userId: userId.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: normalizedName,
                blockedAt: now
            )
        } else {
            blockedUsers.append(
                BlockedUser(
                    id: id,
                    userId: userId.trimmingCharacters(in: .whitespacesAndNewlines),
                    displayName: normalizedName,
                    blockedAt: now
                )
            )
        }

        mutedUsers.removeAll { $0.id == id }
        blockedUsers.sort { lhs, rhs in
            if lhs.blockedAt != rhs.blockedAt { return lhs.blockedAt > rhs.blockedAt }
            return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
        }

        persistBlockedUsers()
        persistMutedUsers()
        appendCommunityAudit(
            kind: .communityUserBlocked,
            title: "ユーザーブロック",
            detail: "target=\(normalizedName) id=\(id)"
        )
        refresh()
    }

    func unblock(id: String) {
        let target = blockedUsers.first(where: { $0.id == id })
        blockedUsers.removeAll { $0.id == id }
        persistBlockedUsers()
        appendCommunityAudit(
            kind: .communityUserUnblocked,
            title: "ブロック解除",
            detail: "target=\(target?.displayName ?? "-") id=\(id)"
        )
        refresh()
    }

    @discardableResult
    func report(userId: String, displayName: String, source: String, reason: String = "abuse") -> SafetyReport? {
        guard canModerateTarget(userId: userId, displayName: displayName) else { return nil }

        let id = makeModerationID(userId: userId, displayName: displayName)
        guard !id.isEmpty else { return nil }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = name.isEmpty ? "Unknown" : name
        if let recent = safetyReports.first(where: {
            $0.targetId == id
            && $0.source == source
            && $0.reason == reason
        }) {
            let elapsed = Date().timeIntervalSince(recent.createdAt)
            if elapsed < reportDedupWindowSeconds {
                return nil
            }
        }

        let report = SafetyReport(
            id: UUID().uuidString,
            targetId: id,
            userId: userId.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: normalizedName,
            source: source,
            reason: reason,
            createdAt: Date()
        )

        safetyReports.insert(report, at: 0)
        if safetyReports.count > safetyReportLimit {
            safetyReports = Array(safetyReports.prefix(safetyReportLimit))
        }
        persistSafetyReports()
        appendCommunityAudit(
            kind: .communitySafetyReported,
            severity: .warning,
            title: "安全レポート記録",
            detail: "target=\(normalizedName) source=\(source) reason=\(reason)"
        )
        return report
    }

    func clearSafetyReports() {
        safetyReports = []
        persistSafetyReports()
    }

    func markInboxAsRead() {
        let seen = latestInboxEventAt ?? Date()
        lastInboxSeenAt = seen
        defaults.set(seen, forKey: lastInboxSeenAtKey)
        unreadInboxCount = 0
    }

    func roomSummary(for roomId: String) -> RoomActivitySummary? {
        roomSummaries.first(where: { $0.roomId == roomId })
    }

    var profileShareText: String {
        let badgeLine = profileSeasonBadgeText.map { "称号: \($0)" } ?? "称号: -"
        return """
        MyDailyPhrase Community
        Name: \(profileDisplayName)
        User ID: \(profileUserId)
        \(badgeLine)
        """
    }

    var referralInviteShareText: String {
        """
        MyDailyPhrase 招待コード: \(referralCode)
        招待成立でお互いガチャ券 +\(ReferralProgram.inviteeRewardTickets)
        """
    }

    var myWeeklyRankSummaryText: String {
        guard let rank = myWeeklyRank, let entry = myWeeklyEntry else {
            return "今週のランキングデータを収集中です"
        }
        return "今週のあなた: #\(rank) \(entry.name) / \(primaryScoreText(entry))"
    }

    var weeklyMissionSummaryText: String {
        if weeklyMission.goals.isEmpty || weeklyMission.seasonRules.isEmpty {
            return "週次ミッションを準備中です"
        }
        if weeklyMission.canClaim {
            let tierName = weeklyMission.achievedTier?.title ?? "Bronze"
            if let rewardName = weeklyMission.achievedRule.flatMap({ weeklySeasonRewardName(for: $0) }) {
                return "今週の\(tierName)報酬を受け取れます（チケット+\(weeklyMission.totalRewardTickets) / 限定デコ \(rewardName)）"
            }
            return "今週の\(tierName)報酬を受け取れます（チケット+\(weeklyMission.totalRewardTickets)）"
        }
        if let claimedTier = weeklyMission.claimedTier {
            return "今週の\(claimedTier.title)報酬は受取済みです"
        }
        if let nextTier = weeklyMission.nextTier {
            return "次の目標は\(nextTier.title)です。交流アクションを積み上げて到達しましょう"
        }
        return "週次ミッション進行中: \(Int((weeklyMission.completionRate * 100).rounded()))%"
    }

    var weeklyMissionShareText: String {
        let tierText = weeklyMission.achievedTier?.title ?? "未達成"
        let goalLines = weeklyMission.goals.map { goal in
            "\(goal.title) \(goal.current)/\(goal.target)"
        }
        let header = "MyDailyPhrase 週次ミッション"
        let seasonLine = "シーズン: \(tierText)"
        let reward = "報酬: チケット+\(weeklyMission.totalRewardTickets)"
        let decoReward = weeklyMission.achievedRule.flatMap { weeklySeasonRewardName(for: $0) }

        var lines = [header, seasonLine] + goalLines + [reward]
        if let decoReward {
            lines.append("限定デコ: \(decoReward)")
        }
        lines.append("#MyDailyPhrase")
        return lines.joined(separator: "\n")
    }

    var weeklyRivalHintText: String {
        if let rival = weeklyRivalAbove {
            return "次の目標: \(rival.name) を追い越す（\(weeklyRivalGapText(to: rival))）"
        }
        if myWeeklyEntry != nil {
            return "現在トップです。このままキープしましょう"
        }
        if let rival = weeklyRivalBelow {
            return "まずは \(rival.name) を超えよう"
        }
        return "ランキングデータを収集中です"
    }

    var weeklyRankingShareText: String {
        if weeklyRanking.isEmpty {
            return "MyDailyPhrase Weekly Ranking\nデータを集計中です。#MyDailyPhrase"
        }

        let header = "MyDailyPhrase Weekly Ranking (\(weeklyRankingMetric.title))"
        let topLines = weeklyRanking.prefix(3).enumerated().map { index, entry in
            "#\(index + 1) \(entry.name) \(primaryScoreText(entry))"
        }
        let selfLine: String
        if let rank = myWeeklyRank, let entry = myWeeklyEntry {
            let badgeSuffix = entry.seasonBadgeText.map { " [\($0)]" } ?? ""
            selfLine = "あなた: #\(rank) \(primaryScoreText(entry))\(badgeSuffix)"
        } else {
            selfLine = "あなた: 集計中"
        }
        return ([header] + topLines + [selfLine, "#MyDailyPhrase"]).joined(separator: "\n")
    }

    func trendShareText(for trend: WeeklyTrend) -> String {
        let roomText = trend.roomSample.map { "room: \($0)" } ?? "room: public"
        return """
        MyDailyPhrase 今週のバズお題
        \(trend.prompt)
        投稿 \(trend.postCount) / 参加者 \(trend.participantCount) / 反応 \(trend.reactionCount)
        \(roomText)
        #MyDailyPhrase #3行日記 #自己分析
        """
    }

    func buildTrendChallengeURL(for trend: WeeklyTrend) -> URL? {
        let prompt = trend.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }
        let dateKey = DateKey.todayKey(timeZone: .current)
        return makeChallengeShareURL(dateKey, prompt)
    }

    func trendChallenges(for trend: WeeklyTrend, limit: Int? = nil) -> [TrendChallengeItem] {
        let list = trendChallengeIndex[trend.id] ?? []
        guard let limit else { return list }
        return Array(list.prefix(max(0, limit)))
    }

    func trendChallengeCount(for trend: WeeklyTrend) -> Int {
        trendChallengeIndex[trend.id]?.count ?? 0
    }

    func recordReferralInviteShared() {
        appendCommunityAudit(
            kind: .communityInviteShared,
            title: "招待リンク共有",
            detail: "code=\(referralCode)"
        )
    }

    func recordWeeklyRankingShared() {
        appendCommunityAudit(
            kind: .communityWeeklyRankingShared,
            title: "週次ランキング共有",
            detail: "metric=\(weeklyRankingMetric.rawValue) rank=\(myWeeklyRank.map(String.init) ?? "-")"
        )
    }

    func recordWeeklyTrendShared(_ trend: WeeklyTrend) {
        appendCommunityAudit(
            kind: .communityWeeklyRankingShared,
            title: "バズお題共有",
            detail: "prompt=\(trend.prompt) posts=\(trend.postCount) reactions=\(trend.reactionCount)"
        )
    }

    @discardableResult
    func claimWeeklyMissionReward() -> String {
        guard weeklyMission.canClaim,
              let tier = weeklyMission.achievedTier,
              let achievedRule = weeklyMission.achievedRule else {
            return "受け取り可能な報酬がありません"
        }

        let me = getMyProfile()
        let actorHint = me.userId.isEmpty ? nil : String(me.userId.suffix(8))
        let reward = weeklyMission.totalRewardTickets

        var ownedCounts = me.ownedDecorationCounts
        var rewardDecorationName: String? = nil
        var selectedDecorationId: String? = nil
        var claimedDecorationId: String? = nil

        if let rewardDecorationId = achievedRule.rewardDecorationId,
           let rewardDecoration = CardDecorationCatalog.byId(rewardDecorationId) {
            let existingCount = ownedCounts[rewardDecoration.id] ?? 0
            ownedCounts[rewardDecoration.id] = existingCount + 1
            rewardDecorationName = rewardDecoration.name
            claimedDecorationId = rewardDecoration.id
            if existingCount == 0 {
                selectedDecorationId = rewardDecoration.id
            }
        }

        _ = updateMyProfile(
            selectedDecorationId: selectedDecorationId,
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .community,
                kind: .communityWeeklyMissionClaimed,
                title: "週次ミッション報酬受取",
                detail: "week=\(weeklyMission.weekKey) tier=\(tier.rawValue) reward=\(reward) rankBonus=\(weeklyMission.rankingBonusTickets) creatorPass=\(weeklyMission.creatorPassActive ? "1" : "0") deco=\(claimedDecorationId ?? "-")",
                actorHint: actorHint
            ),
            ownedDecorationCounts: ownedCounts,
            addGachaTickets: reward
        )
        defaults.set(weeklyMission.weekKey, forKey: weeklyMissionClaimedWeekKey)
        defaults.set(tier.rawValue, forKey: weeklyMissionClaimedTierKey)
        defaults.set(claimedDecorationId, forKey: weeklyMissionClaimedDecorationKey)
        refresh()

        if let rewardDecorationName {
            return "週次ミッション報酬を受け取りました（限定デコ: \(rewardDecorationName)）"
        }
        return "週次ミッション報酬を受け取りました"
    }

    func weeklySeasonRequirementText(for rule: WeeklySeasonRule) -> String {
        var lines: [String] = [
            "連続 \(rule.streakTarget)日",
            "シェア \(rule.shareTarget)",
            "リアクション \(rule.reactionTarget)"
        ]
        if let rankTop = rule.rankTop {
            lines.append("ランキング Top\(rankTop)")
        }
        return lines.joined(separator: " / ")
    }

    func weeklySeasonRewardName(for rule: WeeklySeasonRule) -> String? {
        guard let id = rule.rewardDecorationId else { return nil }
        return CardDecorationCatalog.byId(id)?.name ?? id
    }

    func weeklySeasonRewardText(for rule: WeeklySeasonRule) -> String {
        let ticketText = "チケット +\(rule.rewardTickets)"
        guard let rewardName = weeklySeasonRewardName(for: rule) else { return ticketText }
        return "\(ticketText) / 限定デコ \(rewardName)"
    }

    func weeklySeasonHasLimitedDecoration(for rule: WeeklySeasonRule) -> Bool {
        guard let id = rule.rewardDecorationId else { return false }
        return CardDecorationCatalog.isSeasonLimited(id)
    }

    func weeklySeasonStatusText(for rule: WeeklySeasonRule) -> String {
        if weeklyMission.claimedTier == rule.tier {
            return "受取済み"
        }
        if weeklyMission.unlockedTiers.contains(rule.tier) {
            return "達成"
        }
        if let rankTop = rule.rankTop, let rank = weeklyMission.myRank, rank > rankTop {
            return "順位条件: Top\(rankTop)以内"
        }
        return "未達成"
    }

    func weeklyRivalGapText(to target: WeeklyRankingEntry) -> String {
        guard let me = myWeeklyEntry else { return "差分を計測中" }
        switch weeklyRankingMetric {
        case .streak:
            let gap = max(1, target.streakDays - me.streakDays)
            return "連続記録 +\(gap)日"
        case .shares:
            let gap = max(1, target.shareCount - me.shareCount)
            return "シェア +\(gap)"
        case .reactions:
            let gap = max(1, target.reactionCount - me.reactionCount)
            return "リアクション +\(gap)"
        }
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
        appendCommunityAudit(
            kind: .communityChallengeImported,
            title: "チャレンジ取込",
            detail: "challengeId=\(challenge.id) prompt=\(challenge.link.prompt)"
        )
    }

    // MARK: - Room timeline

    private func updateUnreadCount(
        inboxChallenges: [ChallengeEvent],
        inboxComments: [CommentEvent],
        inboxReactions: [ReactionEvent],
        inboxInvites: [RoomInviteEvent]
    ) {
        latestInboxEventAt = (
            inboxChallenges.map(\.createdAt)
            + inboxComments.map(\.createdAt)
            + inboxReactions.map(\.createdAt)
            + inboxInvites.map(\.createdAt)
        ).max()

        if let seen = lastInboxSeenAt {
            let challengeUnread = inboxChallenges.filter { $0.createdAt > seen }.count
            let commentUnread = inboxComments.filter { $0.createdAt > seen }.count
            let reactionUnread = inboxReactions.filter { $0.createdAt > seen }.count
            let inviteUnread = inboxInvites.filter { $0.createdAt > seen }.count
            unreadInboxCount = challengeUnread + commentUnread + reactionUnread + inviteUnread
        } else {
            unreadInboxCount = inboxChallenges.count + inboxComments.count + inboxReactions.count + inboxInvites.count
        }
    }

    private func shouldShowInbound(userId: String, displayName: String) -> Bool {
        !isBlocked(userId: userId, displayName: displayName)
        && !isMuted(userId: userId, displayName: displayName)
    }

    private func isSelfTarget(userId: String, displayName: String) -> Bool {
        let targetUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentUserId = profileUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !targetUserId.isEmpty && !currentUserId.isEmpty {
            return targetUserId == currentUserId
        }

        let targetName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentName = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty, !currentName.isEmpty else { return false }
        return targetName.caseInsensitiveCompare(currentName) == .orderedSame
    }

    private func isMuted(userId: String, displayName: String) -> Bool {
        let id = makeModerationID(userId: userId, displayName: displayName)
        guard !id.isEmpty else { return false }
        return mutedUsers.contains(where: { $0.id == id })
    }

    private func isBlocked(userId: String, displayName: String) -> Bool {
        let id = makeModerationID(userId: userId, displayName: displayName)
        guard !id.isEmpty else { return false }
        return blockedUsers.contains(where: { $0.id == id })
    }

    private func makeModerationID(userId: String, displayName: String) -> String {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !uid.isEmpty {
            return "id:\(uid)"
        }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !name.isEmpty {
            return "name:\(name)"
        }
        return ""
    }

    private func persistMutedUsers() {
        if let data = try? JSONEncoder().encode(mutedUsers) {
            defaults.set(data, forKey: mutedUsersKey)
        } else {
            defaults.removeObject(forKey: mutedUsersKey)
        }
    }

    private func persistBlockedUsers() {
        if let data = try? JSONEncoder().encode(blockedUsers) {
            defaults.set(data, forKey: blockedUsersKey)
        } else {
            defaults.removeObject(forKey: blockedUsersKey)
        }
    }

    private func persistSafetyReports() {
        if let data = try? JSONEncoder().encode(safetyReports) {
            defaults.set(data, forKey: safetyReportsKey)
        } else {
            defaults.removeObject(forKey: safetyReportsKey)
        }
    }

    private func rebuildWeeklyRanking(
        myUserId: String,
        mySeasonBadge: (text: String, level: Int)?,
        inboxChallenges: [ChallengeEvent],
        outboxChallenges: [ChallengeEvent],
        inboxComments: [CommentEvent],
        outboxComments: [CommentEvent],
        inboxReactions: [ReactionEvent],
        outboxReactions: [ReactionEvent],
        inboxInvites: [RoomInviteEvent],
        outboxInvites: [RoomInviteEvent]
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
            weeklyRanking = []
            weeklyRankingWindowText = "-"
            myWeeklyRank = nil
            myWeeklyEntry = nil
            return
        }

        let weekEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = .current
        dateFormatter.dateFormat = "M/d"
        weeklyRankingWindowText = "\(dateFormatter.string(from: windowStart)) - \(dateFormatter.string(from: todayStart))"

        struct Accumulator {
            var userId: String
            var name: String
            var shareCount: Int
            var reactionCount: Int
            var totalActions: Int
            var latestAt: Date
            var activeDateKeys: Set<String>
        }

        var map: [String: Accumulator] = [:]
        map.reserveCapacity(24)

        func dateKey(for date: Date) -> String {
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            let year = comps.year ?? 0
            let month = comps.month ?? 0
            let day = comps.day ?? 0
            return String(format: "%04d%02d%02d", year, month, day)
        }

        func makeIdentity(userId: String, displayName: String) -> (key: String, userId: String, name: String)? {
            let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUserId.isEmpty || !trimmedName.isEmpty else { return nil }
            if !trimmedUserId.isEmpty {
                return ("id:\(trimmedUserId)", trimmedUserId, trimmedName.isEmpty ? "Unknown" : trimmedName)
            }
            let normalizedName = trimmedName.isEmpty ? "Unknown" : trimmedName
            return ("name:\(normalizedName.lowercased())", "", normalizedName)
        }

        func accumulate(
            userId: String,
            displayName: String,
            at date: Date,
            isShare: Bool,
            isReaction: Bool
        ) {
            guard date >= windowStart && date < weekEnd else { return }
            guard let identity = makeIdentity(userId: userId, displayName: displayName) else { return }

            var item = map[identity.key] ?? Accumulator(
                userId: identity.userId,
                name: identity.name,
                shareCount: 0,
                reactionCount: 0,
                totalActions: 0,
                latestAt: date,
                activeDateKeys: []
            )
            item.totalActions += 1
            if isShare { item.shareCount += 1 }
            if isReaction { item.reactionCount += 1 }
            if date > item.latestAt { item.latestAt = date }
            item.activeDateKeys.insert(dateKey(for: date))
            map[identity.key] = item
        }

        for event in inboxChallenges + outboxChallenges {
            accumulate(
                userId: event.link.fromId,
                displayName: event.link.fromName,
                at: event.createdAt,
                isShare: true,
                isReaction: false
            )
        }
        for event in inboxReactions + outboxReactions {
            accumulate(
                userId: event.link.fromId,
                displayName: event.link.fromName,
                at: event.createdAt,
                isShare: false,
                isReaction: true
            )
        }
        for event in inboxComments + outboxComments {
            accumulate(
                userId: event.link.fromId,
                displayName: event.link.fromName,
                at: event.createdAt,
                isShare: false,
                isReaction: false
            )
        }
        for event in inboxInvites + outboxInvites {
            accumulate(
                userId: event.link.fromId,
                displayName: event.link.fromName,
                at: event.createdAt,
                isShare: false,
                isReaction: false
            )
        }

        func streakDays(from activeKeys: Set<String>) -> Int {
            guard !activeKeys.isEmpty else { return 0 }
            var count = 0
            var cursor = todayStart
            while count < 7 {
                let key = dateKey(for: cursor)
                if activeKeys.contains(key) {
                    count += 1
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                    cursor = previous
                } else {
                    break
                }
            }
            return count
        }

        let myTrimmedId = myUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        weeklyRanking = map.values.map { item in
            let isMe = !myTrimmedId.isEmpty && item.userId == myTrimmedId
            return WeeklyRankingEntry(
                id: item.userId.isEmpty ? "name:\(item.name.lowercased())" : item.userId,
                name: item.name,
                userId: item.userId,
                streakDays: streakDays(from: item.activeDateKeys),
                shareCount: item.shareCount,
                reactionCount: item.reactionCount,
                totalActions: item.totalActions,
                latestAt: item.latestAt,
                isMe: isMe,
                seasonBadgeText: isMe ? mySeasonBadge?.text : nil,
                seasonBadgeLevel: isMe ? (mySeasonBadge?.level ?? 0) : 0
            )
        }

        sortWeeklyRanking()
    }

    private func rebuildWeeklyTrends(
        inboxChallenges: [ChallengeEvent],
        outboxChallenges: [ChallengeEvent],
        inboxComments: [CommentEvent],
        outboxComments: [CommentEvent],
        inboxReactions: [ReactionEvent],
        outboxReactions: [ReactionEvent]
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart) else {
            weeklyTrends = []
            trendChallengeIndex = [:]
            return
        }
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        struct TrendAccumulator {
            var prompt: String
            var postCount: Int
            var participantKeys: Set<String>
            var commentCount: Int
            var reactionCount: Int
            var latestAt: Date
            var representativeDateKey: String
            var roomSample: String?
        }

        var trends: [String: TrendAccumulator] = [:]
        var challengePromptKeyById: [String: String] = [:]
        var trendChallengesByPromptKey: [String: [TrendChallengeItem]] = [:]
        var commentCountByChallengeId: [String: Int] = [:]
        var reactionCountByChallengeId: [String: Int] = [:]
        trends.reserveCapacity(24)
        challengePromptKeyById.reserveCapacity(48)
        trendChallengesByPromptKey.reserveCapacity(24)
        commentCountByChallengeId.reserveCapacity(64)
        reactionCountByChallengeId.reserveCapacity(64)

        func participantKey(userId: String, name: String) -> String {
            let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !uid.isEmpty { return "id:\(uid)" }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmedName.isEmpty ? "unknown" : "name:\(trimmedName)"
        }

        for comment in inboxComments + outboxComments {
            guard comment.createdAt >= windowStart, comment.createdAt < weekEnd else { continue }
            guard let challengeId = comment.link.toChallengeId else { continue }
            commentCountByChallengeId[challengeId, default: 0] += 1
        }

        for reaction in inboxReactions + outboxReactions {
            guard reaction.createdAt >= windowStart, reaction.createdAt < weekEnd else { continue }
            guard let challengeId = reaction.link.toChallengeId else { continue }
            reactionCountByChallengeId[challengeId, default: 0] += 1
        }

        for challenge in inboxChallenges + outboxChallenges {
            guard challenge.createdAt >= windowStart, challenge.createdAt < weekEnd else { continue }
            let prompt = challenge.link.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { continue }

            let key = Self.canonicalPromptKey(prompt)
            challengePromptKeyById[challenge.id] = key

            var accumulator = trends[key] ?? TrendAccumulator(
                prompt: prompt,
                postCount: 0,
                participantKeys: [],
                commentCount: 0,
                reactionCount: 0,
                latestAt: challenge.createdAt,
                representativeDateKey: challenge.link.dateKey,
                roomSample: challenge.link.room
            )

            accumulator.postCount += 1
            accumulator.participantKeys.insert(
                participantKey(userId: challenge.link.fromId, name: challenge.link.fromName)
            )
            if challenge.createdAt > accumulator.latestAt {
                accumulator.latestAt = challenge.createdAt
            }
            if accumulator.roomSample == nil {
                accumulator.roomSample = challenge.link.room
            }
            trends[key] = accumulator

            let fromName = challenge.link.fromName.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = TrendChallengeItem(
                id: "\(challenge.id)-\(challenge.box.rawValue)",
                challengeId: challenge.id,
                prompt: prompt,
                fromName: fromName.isEmpty ? "Unknown" : fromName,
                fromId: challenge.link.fromId,
                room: challenge.link.room,
                dateKey: challenge.link.dateKey,
                createdAt: challenge.createdAt,
                commentCount: commentCountByChallengeId[challenge.id] ?? 0,
                reactionCount: reactionCountByChallengeId[challenge.id] ?? 0,
                isMine: challenge.box == .outbox
            )
            trendChallengesByPromptKey[key, default: []].append(item)
        }

        for comment in inboxComments + outboxComments {
            guard comment.createdAt >= windowStart, comment.createdAt < weekEnd else { continue }
            guard let challengeId = comment.link.toChallengeId,
                  let promptKey = challengePromptKeyById[challengeId],
                  var accumulator = trends[promptKey] else { continue }
            accumulator.commentCount += 1
            trends[promptKey] = accumulator
        }

        for reaction in inboxReactions + outboxReactions {
            guard reaction.createdAt >= windowStart, reaction.createdAt < weekEnd else { continue }
            guard let challengeId = reaction.link.toChallengeId,
                  let promptKey = challengePromptKeyById[challengeId],
                  var accumulator = trends[promptKey] else { continue }
            accumulator.reactionCount += 1
            trends[promptKey] = accumulator
        }

        trendChallengeIndex = trendChallengesByPromptKey.mapValues { items in
            items.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id < rhs.id
            }
        }

        weeklyTrends = trends.map { key, value in
            let engagementScore = value.postCount * 3 + value.commentCount * 2 + value.reactionCount
            return WeeklyTrend(
                id: key,
                prompt: value.prompt,
                postCount: value.postCount,
                participantCount: value.participantKeys.count,
                commentCount: value.commentCount,
                reactionCount: value.reactionCount,
                engagementScore: engagementScore,
                latestAt: value.latestAt,
                representativeDateKey: value.representativeDateKey,
                roomSample: value.roomSample
            )
        }
        .sorted { lhs, rhs in
            if lhs.engagementScore != rhs.engagementScore { return lhs.engagementScore > rhs.engagementScore }
            if lhs.postCount != rhs.postCount { return lhs.postCount > rhs.postCount }
            if lhs.latestAt != rhs.latestAt { return lhs.latestAt > rhs.latestAt }
            return lhs.prompt.localizedCompare(rhs.prompt) == .orderedAscending
        }
    }

    private func publishWeeklyTrendUpdateIfNeeded(
        previousTopTrend: WeeklyTrend?,
        currentTopTrend: WeeklyTrend?
    ) {
        guard let currentTopTrend else { return }

        let previousDigest = previousTopTrend.map(Self.weeklyTrendDigest)
        let currentDigest = Self.weeklyTrendDigest(currentTopTrend)
        guard previousDigest != currentDigest else { return }

        NotificationCenter.default.post(
            name: .communityTrendDidUpdate,
            object: nil,
            userInfo: [
                "prompt": currentTopTrend.prompt,
                "engagementScore": currentTopTrend.engagementScore,
                "postCount": currentTopTrend.postCount,
                "reactionCount": currentTopTrend.reactionCount
            ]
        )
    }

    private static func weeklyTrendDigest(_ trend: WeeklyTrend) -> String {
        "\(trend.id)|\(trend.postCount)|\(trend.participantCount)|\(trend.commentCount)|\(trend.reactionCount)|\(trend.engagementScore)"
    }

    private static func canonicalPromptKey(_ prompt: String) -> String {
        prompt
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func sortWeeklyRanking() {
        weeklyRanking.sort { lhs, rhs in
            switch weeklyRankingMetric {
            case .streak:
                if lhs.streakDays != rhs.streakDays { return lhs.streakDays > rhs.streakDays }
                if lhs.shareCount != rhs.shareCount { return lhs.shareCount > rhs.shareCount }
                if lhs.reactionCount != rhs.reactionCount { return lhs.reactionCount > rhs.reactionCount }
            case .shares:
                if lhs.shareCount != rhs.shareCount { return lhs.shareCount > rhs.shareCount }
                if lhs.streakDays != rhs.streakDays { return lhs.streakDays > rhs.streakDays }
                if lhs.reactionCount != rhs.reactionCount { return lhs.reactionCount > rhs.reactionCount }
            case .reactions:
                if lhs.reactionCount != rhs.reactionCount { return lhs.reactionCount > rhs.reactionCount }
                if lhs.streakDays != rhs.streakDays { return lhs.streakDays > rhs.streakDays }
                if lhs.shareCount != rhs.shareCount { return lhs.shareCount > rhs.shareCount }
            }
            if lhs.totalActions != rhs.totalActions { return lhs.totalActions > rhs.totalActions }
            if lhs.latestAt != rhs.latestAt { return lhs.latestAt > rhs.latestAt }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
        rebuildWeeklyRankHighlight()
    }

    private func rebuildWeeklyRankHighlight() {
        if let index = weeklyRanking.firstIndex(where: { $0.isMe }) {
            myWeeklyRank = index + 1
            myWeeklyEntry = weeklyRanking[index]
            weeklyRivalAbove = index > 0 ? weeklyRanking[index - 1] : nil
            weeklyRivalBelow = (index + 1) < weeklyRanking.count ? weeklyRanking[index + 1] : nil
            return
        }
        myWeeklyRank = nil
        myWeeklyEntry = nil
        weeklyRivalAbove = nil
        weeklyRivalBelow = weeklyRanking.first
    }

    private func primaryScoreText(_ entry: WeeklyRankingEntry) -> String {
        switch weeklyRankingMetric {
        case .streak:
            return "連続 \(entry.streakDays)日"
        case .shares:
            return "シェア \(entry.shareCount)"
        case .reactions:
            return "リアクション \(entry.reactionCount)"
        }
    }

    private func rebuildWeeklyMission() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let weekKey = Self.weekKey(for: Date(), calendar: calendar)
        let claimedWeek = defaults.string(forKey: weeklyMissionClaimedWeekKey)
        if claimedWeek != weekKey {
            defaults.removeObject(forKey: weeklyMissionClaimedDecorationKey)
        }
        let claimedTierRaw = defaults.string(forKey: weeklyMissionClaimedTierKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let claimedTier: WeeklySeasonTier? = {
            guard claimedWeek == weekKey else { return nil }
            guard let claimedTierRaw else { return .bronze } // 旧データ互換
            return WeeklySeasonTier(rawValue: claimedTierRaw) ?? .bronze
        }()
        let creatorPassActive = isCreatorPassActiveProvider()
        let me = myWeeklyEntry

        let seasonRules: [WeeklySeasonRule] = [
            WeeklySeasonRule(
                tier: .bronze,
                streakTarget: 2,
                shareTarget: 3,
                reactionTarget: 4,
                rankTop: nil,
                rewardTickets: weeklyMissionBaseRewardTickets,
                rewardDecorationId: seasonRewardDecoration(for: .bronze, weekKey: weekKey)?.id
            ),
            WeeklySeasonRule(
                tier: .silver,
                streakTarget: 4,
                shareTarget: 7,
                reactionTarget: 12,
                rankTop: 30,
                rewardTickets: weeklyMissionBaseRewardTickets + 3,
                rewardDecorationId: seasonRewardDecoration(for: .silver, weekKey: weekKey)?.id
            ),
            WeeklySeasonRule(
                tier: .gold,
                streakTarget: 6,
                shareTarget: 12,
                reactionTarget: 20,
                rankTop: 10,
                rewardTickets: weeklyMissionBaseRewardTickets + 8,
                rewardDecorationId: seasonRewardDecoration(for: .gold, weekKey: weekKey)?.id
            )
        ]

        let maxRule = seasonRules.last
        let goals: [WeeklyMissionGoal] = [
            WeeklyMissionGoal(
                id: "streak",
                title: "連続記録",
                current: me?.streakDays ?? 0,
                target: maxRule?.streakTarget ?? 0
            ),
            WeeklyMissionGoal(
                id: "shares",
                title: "シェア",
                current: me?.shareCount ?? 0,
                target: maxRule?.shareTarget ?? 0
            ),
            WeeklyMissionGoal(
                id: "reactions",
                title: "リアクション",
                current: me?.reactionCount ?? 0,
                target: maxRule?.reactionTarget ?? 0
            )
        ]

        func isRuleUnlocked(_ rule: WeeklySeasonRule) -> Bool {
            guard let me else { return false }
            guard me.streakDays >= rule.streakTarget else { return false }
            guard me.shareCount >= rule.shareTarget else { return false }
            guard me.reactionCount >= rule.reactionTarget else { return false }
            if let rankTop = rule.rankTop {
                guard let rank = myWeeklyRank else { return false }
                guard rank <= rankTop else { return false }
            }
            return true
        }

        let unlockedTiers = Set(
            seasonRules
                .filter(isRuleUnlocked)
                .map(\.tier)
        )
        let achievedTier = seasonRules
            .reversed()
            .first(where: isRuleUnlocked)?
            .tier
        let nextTier = seasonRules.first(where: { !unlockedTiers.contains($0.tier) })?.tier

        let rankingBonus: Int = {
            guard let rank = myWeeklyRank else { return 0 }
            if rank <= 3 { return weeklyMissionRankingTop3BonusTickets }
            if rank <= 10 { return weeklyMissionRankingTop10BonusTickets }
            if rank <= 30 { return weeklyMissionRankingTop30BonusTickets }
            return 0
        }()

        weeklyMission = WeeklyMissionStatus(
            weekKey: weekKey,
            goals: goals,
            seasonRules: seasonRules,
            achievedTier: achievedTier,
            nextTier: nextTier,
            unlockedTiers: unlockedTiers,
            claimedTier: claimedTier,
            myRank: myWeeklyRank,
            rankingBonusTickets: rankingBonus,
            creatorPassBonusTickets: weeklyMissionCreatorPassBonusTickets,
            creatorPassActive: creatorPassActive
        )
    }

    private func seasonRewardDecoration(for tier: WeeklySeasonTier, weekKey: String) -> CardDecoration? {
        let candidates = CardDecorationCatalog.seasonRewardCandidates(tierRaw: tier.rawValue)
        guard !candidates.isEmpty else { return nil }
        let seed = "\(weekKey)#\(tier.rawValue)#seasonReward"
        let index = Int(stableHash64(seed) % UInt64(candidates.count))
        return candidates[index]
    }

    private func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func weekKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }

    private func rebuildInsights(myUserId: String) {
        let allChallenges = inboxChallenges + outboxChallenges
        let allComments = inboxComments + outboxComments
        let allReactions = inboxReactions + outboxReactions
        let allInvites = inboxRoomInvites + outboxRoomInvites

        let totalEvents = allChallenges.count + allComments.count + allReactions.count + allInvites.count
        let latestEventAt = (
            allChallenges.map(\.createdAt)
            + allComments.map(\.createdAt)
            + allReactions.map(\.createdAt)
            + allInvites.map(\.createdAt)
        ).max()

        struct MemberAccumulator {
            var name: String
            var activityCount: Int
            var latestSeenAt: Date
        }
        var memberMap: [String: MemberAccumulator] = [:]
        memberMap.reserveCapacity(16)

        func accumulate(id rawId: String, name rawName: String, at date: Date) {
            let id = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty || !name.isEmpty else { return }

            let key = id.isEmpty ? "name:\(name)" : id
            if var found = memberMap[key] {
                found.activityCount += 1
                if date > found.latestSeenAt { found.latestSeenAt = date }
                if found.name.isEmpty, !name.isEmpty { found.name = name }
                memberMap[key] = found
            } else {
                memberMap[key] = .init(
                    name: name.isEmpty ? "Unknown" : name,
                    activityCount: 1,
                    latestSeenAt: date
                )
            }
        }

        for ev in allChallenges {
            accumulate(id: ev.link.fromId, name: ev.link.fromName, at: ev.createdAt)
        }
        for ev in allComments {
            accumulate(id: ev.link.fromId, name: ev.link.fromName, at: ev.createdAt)
        }
        for ev in allReactions {
            accumulate(id: ev.link.fromId, name: ev.link.fromName, at: ev.createdAt)
        }
        for ev in allInvites {
            accumulate(id: ev.link.fromId, name: ev.link.fromName, at: ev.createdAt)
        }

        activeMembers = memberMap
            .map { key, value in
                MemberSummary(
                    id: key,
                    name: value.name,
                    activityCount: value.activityCount,
                    latestSeenAt: value.latestSeenAt,
                    isMe: key == myUserId
                )
            }
            .sorted { lhs, rhs in
                if lhs.activityCount != rhs.activityCount { return lhs.activityCount > rhs.activityCount }
                if lhs.latestSeenAt != rhs.latestSeenAt { return lhs.latestSeenAt > rhs.latestSeenAt }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
            .prefix(12)
            .map { $0 }

        pulse = CommunityPulse(
            rooms: rooms.count,
            challenges: allChallenges.count,
            comments: allComments.count,
            reactions: allReactions.count,
            invites: allInvites.count,
            activeMembers: activeMembers.count,
            totalEvents: totalEvents,
            latestEventAt: latestEventAt
        )

        let roomFilterText = roomFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        var roomIds = Set(rooms.map(\.roomId))
        roomIds.formUnion(allChallenges.compactMap(\.link.room))
        roomIds.formUnion(allComments.compactMap(\.link.room))
        roomIds.formUnion(allReactions.compactMap(\.link.room))
        roomIds.formUnion(allInvites.map(\.link.roomId))
        if !roomFilterText.isEmpty {
            roomIds = [roomFilterText]
        }

        roomSummaries = roomIds
            .map { roomId in
                let ch = allChallenges.filter { $0.link.room == roomId }
                let cm = allComments.filter { $0.link.room == roomId }
                let re = allReactions.filter { $0.link.room == roomId }
                let inv = allInvites.filter { $0.link.roomId == roomId }

                var participants = Set<String>()
                for ev in ch { participants.insert(ev.link.fromId) }
                for ev in cm { participants.insert(ev.link.fromId) }
                for ev in re { participants.insert(ev.link.fromId) }
                for ev in inv { participants.insert(ev.link.fromId) }

                let latest = (
                    ch.map(\.createdAt)
                    + cm.map(\.createdAt)
                    + re.map(\.createdAt)
                    + inv.map(\.createdAt)
                ).max()

                let roomName = rooms.first(where: { $0.roomId == roomId })?.roomName
                let events = ch.count + cm.count + re.count + inv.count
                return RoomActivitySummary(
                    roomId: roomId,
                    roomName: roomName,
                    challengeCount: ch.count,
                    commentCount: cm.count,
                    reactionCount: re.count,
                    inviteCount: inv.count,
                    participantCount: participants.count,
                    totalEvents: events,
                    lastEventAt: latest
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalEvents != rhs.totalEvents { return lhs.totalEvents > rhs.totalEvents }
                if lhs.lastEventAt != rhs.lastEventAt { return (lhs.lastEventAt ?? .distantPast) > (rhs.lastEventAt ?? .distantPast) }
                return lhs.roomId.localizedCompare(rhs.roomId) == .orderedAscending
            }
    }

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

    private func appendCommunityAudit(
        kind: SecurityAuditKind,
        severity: SecurityAuditSeverity = .info,
        title: String,
        detail: String
    ) {
        let me = getMyProfile()
        let actorHint = me.userId.isEmpty ? nil : String(me.userId.suffix(8))
        _ = updateMyProfile(
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .community,
                kind: kind,
                severity: severity,
                title: title,
                detail: detail,
                actorHint: actorHint,
                metadata: [
                    "roomFilter": roomFilter.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
            )
        )
    }

    private static func seasonCollectorBadge(for ownedSeasonLimitedCount: Int) -> (text: String, level: Int)? {
        switch ownedSeasonLimitedCount {
        case 9...:
            return ("Season Legend", 4)
        case 6...:
            return ("Season Master", 3)
        case 3...:
            return ("Season Hunter", 2)
        case 1...:
            return ("Season Collector", 1)
        default:
            return nil
        }
    }
}

// MARK: - Thread item / Room feed item

extension CommunityViewModel {
    struct MutedUser: Identifiable, Equatable, Codable {
        let id: String
        let userId: String
        let displayName: String
        let mutedAt: Date
    }

    struct BlockedUser: Identifiable, Equatable, Codable {
        let id: String
        let userId: String
        let displayName: String
        let blockedAt: Date
    }

    struct SafetyReport: Identifiable, Equatable, Codable {
        let id: String
        let targetId: String
        let userId: String
        let displayName: String
        let source: String
        let reason: String
        let createdAt: Date
    }

    struct CommunityPulse: Equatable {
        let rooms: Int
        let challenges: Int
        let comments: Int
        let reactions: Int
        let invites: Int
        let activeMembers: Int
        let totalEvents: Int
        let latestEventAt: Date?

        static let empty = CommunityPulse(
            rooms: 0,
            challenges: 0,
            comments: 0,
            reactions: 0,
            invites: 0,
            activeMembers: 0,
            totalEvents: 0,
            latestEventAt: nil
        )
    }

    struct MemberSummary: Identifiable, Equatable {
        let id: String
        let name: String
        let activityCount: Int
        let latestSeenAt: Date
        let isMe: Bool
    }

    struct RoomActivitySummary: Identifiable, Equatable {
        var id: String { roomId }
        let roomId: String
        let roomName: String?
        let challengeCount: Int
        let commentCount: Int
        let reactionCount: Int
        let inviteCount: Int
        let participantCount: Int
        let totalEvents: Int
        let lastEventAt: Date?
    }

    enum WeeklyRankingMetric: String, CaseIterable, Identifiable {
        case streak
        case shares
        case reactions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .streak: return "連続記録"
            case .shares: return "シェア"
            case .reactions: return "リアクション"
            }
        }
    }

    struct WeeklyRankingEntry: Identifiable, Equatable {
        let id: String
        let name: String
        let userId: String
        let streakDays: Int
        let shareCount: Int
        let reactionCount: Int
        let totalActions: Int
        let latestAt: Date
        let isMe: Bool
        let seasonBadgeText: String?
        let seasonBadgeLevel: Int
    }

    struct WeeklyTrend: Identifiable, Equatable {
        let id: String
        let prompt: String
        let postCount: Int
        let participantCount: Int
        let commentCount: Int
        let reactionCount: Int
        let engagementScore: Int
        let latestAt: Date
        let representativeDateKey: String
        let roomSample: String?
    }

    struct WeeklyMissionGoal: Identifiable, Equatable {
        let id: String
        let title: String
        let current: Int
        let target: Int

        var remaining: Int {
            max(0, target - current)
        }

        var completionRate: Double {
            guard target > 0 else { return 0 }
            return min(1.0, Double(max(0, current)) / Double(target))
        }

        var isCompleted: Bool {
            current >= target
        }
    }

    enum WeeklySeasonTier: String, CaseIterable, Identifiable {
        case bronze
        case silver
        case gold

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bronze:
                return "Bronze"
            case .silver:
                return "Silver"
            case .gold:
                return "Gold"
            }
        }
    }

    struct WeeklySeasonRule: Identifiable, Equatable {
        var id: String { tier.rawValue }
        let tier: WeeklySeasonTier
        let streakTarget: Int
        let shareTarget: Int
        let reactionTarget: Int
        let rankTop: Int?
        let rewardTickets: Int
        let rewardDecorationId: String?
    }

    struct WeeklyMissionStatus: Equatable {
        let weekKey: String
        let goals: [WeeklyMissionGoal]
        let seasonRules: [WeeklySeasonRule]
        let achievedTier: WeeklySeasonTier?
        let nextTier: WeeklySeasonTier?
        let unlockedTiers: Set<WeeklySeasonTier>
        let claimedTier: WeeklySeasonTier?
        let myRank: Int?
        let rankingBonusTickets: Int
        let creatorPassBonusTickets: Int
        let creatorPassActive: Bool

        static let empty = WeeklyMissionStatus(
            weekKey: "",
            goals: [],
            seasonRules: [],
            achievedTier: nil,
            nextTier: nil,
            unlockedTiers: [],
            claimedTier: nil,
            myRank: nil,
            rankingBonusTickets: 0,
            creatorPassBonusTickets: 0,
            creatorPassActive: false
        )

        var completionRate: Double {
            guard !goals.isEmpty else { return 0 }
            let total = goals.reduce(0.0) { $0 + $1.completionRate }
            return min(1.0, total / Double(goals.count))
        }

        var isCompleted: Bool {
            achievedTier != nil
        }

        var achievedRule: WeeklySeasonRule? {
            guard let achievedTier else { return nil }
            return seasonRules.first(where: { $0.tier == achievedTier })
        }

        var totalRewardTickets: Int {
            (achievedRule?.rewardTickets ?? 0)
                + rankingBonusTickets
                + (creatorPassActive ? creatorPassBonusTickets : 0)
        }

        var canClaim: Bool {
            achievedTier != nil && claimedTier == nil
        }
    }

    struct TrendChallengeItem: Identifiable, Equatable {
        let id: String
        let challengeId: String
        let prompt: String
        let fromName: String
        let fromId: String
        let room: String?
        let dateKey: String
        let createdAt: Date
        let commentCount: Int
        let reactionCount: Int
        let isMine: Bool
    }

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
