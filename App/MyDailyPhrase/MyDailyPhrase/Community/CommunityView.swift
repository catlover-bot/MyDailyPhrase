import SwiftUI
import UIKit
import Domain
import Presentation

struct CommunityView: View {
    @StateObject private var vm: CommunityViewModel

    @EnvironmentObject private var store: IAPStore
    @Environment(\.currentDecorationId) private var decorationId

    // ✅ SharePayload で統一
    @State private var isPresentingShareSheet = false
    @State private var shareSheetItems: [Any] = []
    @State private var localStatusMessage: String? = nil

    init(vm: CommunityViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CommunityGradientBackground()
                    .ignoresSafeArea()

                List {
                    profileSection
                    growthLoopSection
                    mutedUsersSection
                    blockedUsersSection
                    safetyReportsSection
                    roomFilterSection
                    pulseSection
                    weeklyRankingSection
                    weeklyMissionSection
                    weeklyTrendSection

                    if showRoomTimeline {
                        roomTimelineSection
                    }

                    roomsSection
                    invitesInboxSection
                    challengesInboxSection
                    challengesOutboxSection
                    commentsInboxSection
                    commentsOutboxSection
                    reactionsInboxSection
                    reactionsOutboxSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .refreshable { refreshAndRead() } // ✅ Pull-to-refresh
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { refreshAndRead() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("更新")
                }
            }
            .task { refreshAndRead() } // ✅ onAppear より多重実行しにくい
            .sheet(isPresented: $isPresentingShareSheet) {
                ShareSheet(activityItems: shareSheetItems)
            }
        }
    }

    // MARK: - Share Helper

    @MainActor
    private func presentShare(text: String, image: UIImage? = nil, url: URL? = nil) {
        shareSheetItems = ShareItemsBuilder.build(text: text, image: image, url: url)
        isPresentingShareSheet = true
    }

    @MainActor
    private func refreshAndRead() {
        vm.refresh()
        vm.markInboxAsRead()
    }

    @MainActor
    private func muteSender(userId: String, name: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            localStatusMessage = "自分自身はミュートできません"
            return
        }
        vm.mute(userId: userId, displayName: name)
        localStatusMessage = "「\(name)」をミュートしました"
    }

    @MainActor
    private func blockSender(userId: String, name: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            localStatusMessage = "自分自身はブロックできません"
            return
        }
        vm.block(userId: userId, displayName: name)
        localStatusMessage = "「\(name)」をブロックしました"
    }

    @MainActor
    private func reportSender(userId: String, name: String, source: String) {
        guard vm.canModerateTarget(userId: userId, displayName: name) else {
            localStatusMessage = "自分自身は通報できません"
            return
        }
        guard let report = vm.report(userId: userId, displayName: name, source: source) else {
            localStatusMessage = "同内容の通報は1分以内に重複登録できません"
            return
        }

        UIPasteboard.general.string = """
        [Safety Report]
        date: \(report.createdAt.ISO8601Format())
        source: \(report.source)
        reason: \(report.reason)
        displayName: \(report.displayName)
        userId: \(report.userId.isEmpty ? "-" : report.userId)
        """
        localStatusMessage = "「\(name)」を通報記録しました（内容をコピー済み）"
    }

    @ViewBuilder
    private func moderationContextMenu(userId: String, name: String, source: String) -> some View {
        Button(role: .destructive) {
            muteSender(userId: userId, name: name)
        } label: {
            Label("「\(name)」をミュート", systemImage: "speaker.slash")
        }

        Button(role: .destructive) {
            blockSender(userId: userId, name: name)
        } label: {
            Label("「\(name)」をブロック", systemImage: "hand.raised")
        }

        Button {
            reportSender(userId: userId, name: name, source: source)
        } label: {
            Label("通報を記録", systemImage: "exclamationmark.bubble")
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Your Profile") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(vm.profileDisplayName)
                                    .font(.headline)
                                if let badge = vm.profileSeasonBadgeText {
                                    Text(badge)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(seasonBadgeColor(level: vm.profileSeasonBadgeLevel).opacity(0.18))
                                        .clipShape(Capsule())
                                }
                            }
                            Text("ID: \(vm.profileShortUserId)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let refreshedAt = vm.lastRefreshedAt {
                            Text(refreshedAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = vm.profileUserId
                            localStatusMessage = "User IDをコピーしました"
                        } label: {
                            Label("IDをコピー", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            presentShare(text: vm.profileShareText)
                        } label: {
                            Label("プロフィール共有", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if let inviteURL = vm.referralInviteURL {
                            Button {
                                presentShare(text: vm.referralInviteShareText, url: inviteURL)
                                vm.recordReferralInviteShared()
                                localStatusMessage = "招待リンクを共有しました"
                            } label: {
                                Label("招待共有", systemImage: "paperplane")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }

                    if let localStatusMessage {
                        Text(localStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var growthLoopSection: some View {
        Section("Growth Loop") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("招待コード")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vm.referralCode)
                                .font(.subheadline.monospaced().weight(.semibold))
                        }
                        Spacer()
                        Text(vm.myWeeklyRankSummaryText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    Text("集計期間: \(vm.weeklyRankingWindowText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        if let inviteURL = vm.referralInviteURL {
                            Button {
                                presentShare(text: vm.referralInviteShareText, url: inviteURL)
                                vm.recordReferralInviteShared()
                                localStatusMessage = "招待リンクを共有しました"
                            } label: {
                                Label("招待リンク共有", systemImage: "person.crop.circle.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button {
                            presentShare(text: vm.weeklyRankingShareText)
                            vm.recordWeeklyRankingShared()
                            localStatusMessage = "週次ランキングを共有しました"
                        } label: {
                            Label("ランキング共有", systemImage: "chart.bar.xaxis")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var mutedUsersSection: some View {
        Section("Muted Users") {
            if vm.mutedUsers.isEmpty {
                Card {
                    Text("ミュート中のユーザーはいません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.mutedUsers) { user in
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(user.userId.isEmpty ? user.id : user.userId)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                vm.unmute(id: user.id)
                                localStatusMessage = "「\(user.displayName)」のミュートを解除しました"
                            } label: {
                                Label("解除", systemImage: "speaker.wave.2")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var blockedUsersSection: some View {
        Section("Blocked Users") {
            if vm.blockedUsers.isEmpty {
                Card {
                    Text("ブロック中のユーザーはいません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.blockedUsers) { user in
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(user.userId.isEmpty ? user.id : user.userId)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                vm.unblock(id: user.id)
                                localStatusMessage = "「\(user.displayName)」のブロックを解除しました"
                            } label: {
                                Label("解除", systemImage: "hand.raised.slash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var safetyReportsSection: some View {
        Section("Safety Reports") {
            if vm.safetyReports.isEmpty {
                Card {
                    Text("通報記録はありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(vm.safetyReports.prefix(5)), id: \.id) { report in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.displayName)
                                .font(.subheadline.weight(.semibold))
                            HStack {
                                Text(report.source)
                                Text(report.reason)
                                Spacer()
                                Text(report.createdAt, style: .time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Button {
                    vm.clearSafetyReports()
                    localStatusMessage = "通報記録をクリアしました"
                } label: {
                    Label("通報記録をクリア", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var pulseSection: some View {
        Section("Community Pulse") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        pulseChip(title: "room", value: "\(vm.pulse.rooms)")
                        pulseChip(title: "イベント", value: "\(vm.pulse.totalEvents)")
                        pulseChip(title: "メンバー", value: "\(vm.pulse.activeMembers)")
                    }

                    HStack(spacing: 10) {
                        pulseChip(title: "Challenge", value: "\(vm.pulse.challenges)")
                        pulseChip(title: "Comment", value: "\(vm.pulse.comments)")
                        pulseChip(title: "Reaction", value: "\(vm.pulse.reactions)")
                    }

                    if let latest = vm.pulse.latestEventAt {
                        Text("最新イベント: \(latest.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if !vm.activeMembers.isEmpty {
                Card("アクティブメンバー") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(vm.activeMembers.prefix(6))) { member in
                            HStack {
                                Text(member.isMe ? "あなた" : member.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(member.activityCount) actions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var weeklyRankingSection: some View {
        Section("Weekly Ranking") {
            Picker("指標", selection: $vm.weeklyRankingMetric) {
                ForEach(CommunityViewModel.WeeklyRankingMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("集計期間: \(vm.weeklyRankingWindowText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("※ あなたのシーズン称号はランキング名の横に表示されます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let rank = vm.myWeeklyRank, let me = vm.myWeeklyEntry {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("あなたの現在地")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text("#\(rank)")
                                .font(.title2.weight(.bold))
                            Text(me.name)
                                .font(.headline)
                            Spacer()
                            Text(primaryScoreText(for: me))
                                .font(.title3.weight(.semibold))
                        }
                        HStack(spacing: 10) {
                            Label("\(me.streakDays)日", systemImage: "flame")
                            Label("\(me.shareCount)", systemImage: "paperplane")
                            Label("\(me.reactionCount)", systemImage: "hand.thumbsup")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if vm.weeklyRanking.isEmpty {
                Card {
                    Text("この期間のランキングデータはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Card {
                    HStack(spacing: 10) {
                        Text("順位")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text("ユーザー")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.weeklyRankingMetric.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(Array(vm.weeklyRanking.prefix(10).enumerated()), id: \.offset) { index, entry in
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            Text("#\(index + 1)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(index < 3 ? .orange : .primary)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    if entry.isMe {
                                        Text("あなた")
                                            .font(.subheadline.weight(.semibold))
                                    } else {
                                        NavigationLink {
                                            UserProfileView(userId: entry.userId, name: entry.name)
                                        } label: {
                                            Text(entry.name)
                                                .font(.subheadline.weight(.semibold))
                                        }
                                    }
                                    if let badge = entry.seasonBadgeText {
                                        Text(badge)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(seasonBadgeColor(level: entry.seasonBadgeLevel).opacity(0.18))
                                            .clipShape(Capsule())
                                    }
                                }
                                HStack(spacing: 10) {
                                    Label("\(entry.streakDays)日", systemImage: "flame")
                                    Label("\(entry.shareCount)", systemImage: "paperplane")
                                    Label("\(entry.reactionCount)", systemImage: "hand.thumbsup")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(primaryScoreText(for: entry))
                                    .font(.headline)
                                Text("actions \(entry.totalActions)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var weeklyTrendSection: some View {
        Section("Buzz Topics") {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今週シェアされたお題から、投稿数と反応数を合算してトレンドを表示します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.isCreatorPassActive
                         ? "Creator Pass: 詳細投稿一覧を全件表示"
                         : "Free: 詳細投稿は3件プレビュー / Creator Passで全件表示")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if vm.weeklyTrends.isEmpty {
                Card {
                    Text("トレンド集計データはまだありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(vm.weeklyTrends.prefix(5).enumerated()), id: \.offset) { index, trend in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(index < 3 ? .orange : .primary)
                                Text(trend.prompt)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Text("投稿 \(trend.postCount)")
                                Text("参加 \(trend.participantCount)")
                                Text("💬 \(trend.commentCount)")
                                Text("👍 \(trend.reactionCount)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                NavigationLink {
                                    WeeklyTrendDetailView(vm: vm, trend: trend)
                                } label: {
                                    Label("投稿一覧 \(vm.trendChallengeCount(for: trend))", systemImage: "list.bullet.rectangle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    let text = vm.trendShareText(for: trend)
                                    let url = vm.buildTrendChallengeURL(for: trend)
                                    presentShare(text: text, url: url)
                                    vm.recordWeeklyTrendShared(trend)
                                    localStatusMessage = "トレンドお題を共有しました"
                                } label: {
                                    Label("共有", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                if let roomSample = trend.roomSample {
                                    Text("room: \(roomSample)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var weeklyMissionSection: some View {
        Section("Weekly Mission") {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("コミュニティ週次ミッション")
                                .font(.subheadline.weight(.semibold))
                            Text(vm.weeklyMission.achievedTier?.title ?? "Unranked")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text("報酬 \(vm.weeklyMission.totalRewardTickets)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: vm.weeklyMission.completionRate, total: 1.0)

                    ForEach(vm.weeklyMission.goals) { goal in
                        HStack {
                            Label(goal.title, systemImage: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(goal.isCompleted ? .green : .secondary)
                            Spacer()
                            Text("\(goal.current)/\(goal.target)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    ForEach(vm.weeklyMission.seasonRules) { rule in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: missionTierIcon(for: rule.tier))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(missionTierTint(for: rule.tier))
                                .frame(width: 18, height: 18)
                                .padding(6)
                                .background(missionTierTint(for: rule.tier).opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(rule.tier.title)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text(vm.weeklySeasonStatusText(for: rule))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(missionTierStatusColor(for: rule))
                                }
                                Text(vm.weeklySeasonRequirementText(for: rule))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Text(vm.weeklySeasonRewardText(for: rule))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if vm.weeklySeasonHasLimitedDecoration(for: rule) {
                                        Text("限定")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.18))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    if let rank = vm.weeklyMission.myRank {
                        Text("現在の順位: #\(rank) / 順位ボーナス +\(vm.weeklyMission.rankingBonusTickets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("順位ボーナスは Top30 / Top10 / Top3 で段階的に増加します")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(vm.weeklyMissionSummaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if vm.weeklyMission.creatorPassActive {
                        Text("Creator Passボーナス: +\(vm.weeklyMission.creatorPassBonusTickets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Creator Pass加入で報酬 +\(vm.weeklyMission.creatorPassBonusTickets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if vm.weeklyMission.canClaim {
                        Button {
                            localStatusMessage = vm.claimWeeklyMissionReward()
                        } label: {
                            Label("報酬を受け取る（チケット+\(vm.weeklyMission.totalRewardTickets)）", systemImage: "gift.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button {
                        presentShare(text: vm.weeklyMissionShareText)
                        localStatusMessage = "週次ミッション進捗を共有しました"
                    } label: {
                        Label("進捗を共有", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if vm.weeklyRivalAbove != nil || vm.weeklyRivalBelow != nil {
                Card("Rival Race") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let rival = vm.weeklyRivalAbove {
                            HStack {
                                Text("次に追い越す相手")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(rival.isMe ? "あなた" : rival.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(primaryScoreText(for: rival))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let rival = vm.weeklyRivalBelow {
                            HStack {
                                Text("すぐ後ろ")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(rival.isMe ? "あなた" : rival.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(primaryScoreText(for: rival))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(vm.weeklyRivalHintText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let rival = vm.weeklyRivalAbove {
                            Text("追い越し目安: \(vm.weeklyRivalGapText(to: rival))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func primaryScoreText(for entry: CommunityViewModel.WeeklyRankingEntry) -> String {
        switch vm.weeklyRankingMetric {
        case .streak:
            return "\(entry.streakDays)d"
        case .shares:
            return "\(entry.shareCount)"
        case .reactions:
            return "\(entry.reactionCount)"
        }
    }

    private func missionTierIcon(for tier: CommunityViewModel.WeeklySeasonTier) -> String {
        switch tier {
        case .bronze:
            return "medal"
        case .silver:
            return "medal.fill"
        case .gold:
            return "trophy.fill"
        }
    }

    private func missionTierTint(for tier: CommunityViewModel.WeeklySeasonTier) -> Color {
        switch tier {
        case .bronze:
            return .brown
        case .silver:
            return .gray
        case .gold:
            return .yellow
        }
    }

    private func missionTierStatusColor(for rule: CommunityViewModel.WeeklySeasonRule) -> Color {
        if vm.weeklyMission.unlockedTiers.contains(rule.tier) {
            return .green
        }
        return rule.rankTop == nil ? .secondary : .orange
    }

    private func seasonBadgeColor(level: Int) -> Color {
        switch level {
        case 4:
            return .orange
        case 3:
            return .yellow
        case 2:
            return .mint
        case 1:
            return .blue
        default:
            return .secondary
        }
    }

    private func pulseChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var roomFilterSection: some View {
        Section("Room Filter") {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("room を入力（空で全件）", text: $vm.roomFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { refreshAndRead() } // ✅ Enterで更新

                    HStack(spacing: 10) {
                        Button {
                            refreshAndRead()
                        } label: {
                            Label("更新", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        if !vm.roomFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                vm.roomFilter = ""
                                refreshAndRead()
                            } label: {
                                Label("解除", systemImage: "xmark.circle")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var showRoomTimeline: Bool {
        !vm.roomFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var roomTimelineSection: some View {
        Section("Room Timeline") {
            if vm.roomTimeline.isEmpty {
                Card {
                    Text("このroomのイベントがありません（リンクで受信した分だけ溜まります）")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.roomTimeline) { item in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title)
                                    .font(.headline)
                                Spacer()
                                Text(item.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var roomsSection: some View {
        Section("Rooms") {
            if vm.rooms.isEmpty {
                Card {
                    Text("参加中の room はありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.rooms) { r in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.roomName ?? r.roomId)
                                        .font(.headline)
                                    if r.roomName != nil {
                                        Text(r.roomId)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }

                            if let summary = vm.roomSummary(for: r.roomId) {
                                HStack(spacing: 12) {
                                    Text("活動 \(summary.totalEvents)")
                                    Text("💬 \(summary.commentCount)")
                                    Text("👍 \(summary.reactionCount)")
                                    Text("👥 \(summary.participantCount)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    guard let url = vm.buildJoinURL(roomId: r.roomId, roomName: r.roomName) else { return }
                                    let text = "Room参加: \(r.roomName ?? r.roomId)\n#MyDailyPhrase"
                                    presentShare(text: text, url: url)
                                } label: {
                                    Label("参加リンク共有", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Spacer()

                                Button {
                                    vm.leave(roomId: r.roomId)
                                } label: {
                                    Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Card("招待リンクを作る") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("招待する roomId（例: tennis）", text: $vm.inviteRoomId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    TextField("roomName（任意）", text: $vm.inviteRoomName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard let url = vm.buildInviteURL() else { return }
                        let title = vm.inviteRoomName.isEmpty ? vm.inviteRoomId : vm.inviteRoomName
                        let text = "Room招待: \(title)\n#MyDailyPhrase"
                        presentShare(text: text, url: url)
                        refreshAndRead()
                    } label: {
                        Label("招待リンクを共有", systemImage: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.inviteRoomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var invitesInboxSection: some View {
        Section("Invites - Inbox") {
            if vm.inboxRoomInvites.isEmpty {
                Card {
                    Text("受信した room 招待はありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxRoomInvites, id: \.id) { inv in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(inv.link.roomName ?? inv.link.roomId)
                                    .font(.headline)
                                Text("from: \(inv.link.fromName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    vm.joinFromInvite(inv)
                                } label: {
                                    Label("参加", systemImage: "person.badge.plus")
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Spacer()

                                Button {
                                    guard let url = vm.buildJoinURL(roomId: inv.link.roomId, roomName: inv.link.roomName) else { return }
                                    let text = "Room参加: \(inv.link.roomName ?? inv.link.roomId)\n#MyDailyPhrase"
                                    presentShare(text: text, url: url)
                                } label: {
                                    Label("参加を共有", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .contextMenu {
                        moderationContextMenu(userId: inv.link.fromId, name: inv.link.fromName, source: "invite_inbox")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var challengesInboxSection: some View {
        Section("Inbox - Challenges") {
            if vm.inboxChallenges.isEmpty {
                Card {
                    Text("受信したチャレンジはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxChallenges, id: \.id) { ev in
                    NavigationLink {
                        ThreadView(
                            challenge: ev,
                            vm: vm,
                            shareItems: { items in
                                shareSheetItems = items
                                isPresentingShareSheet = true
                            }
                        )
                    } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(ev.link.prompt)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Spacer()
                                    let c = vm.commentCount(for: ev.id)
                                    let r = vm.reactionCount(for: ev.id)
                                    if c > 0 { Text("💬 \(c)").font(.caption).foregroundStyle(.secondary) }
                                    if r > 0 { Text("👍 \(r)").font(.caption).foregroundStyle(.secondary) }
                                }

                                Text("from: \(ev.link.fromName)   dateKey: \(ev.link.dateKey)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 12) {
                                    if let room = ev.link.room { Text("room: \(room)") }
                                    if let chain = ev.link.chainId { Text("chain: \(chain)") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contextMenu {
                        moderationContextMenu(userId: ev.link.fromId, name: ev.link.fromName, source: "challenge_inbox")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var challengesOutboxSection: some View {
        Section("Outbox - Challenges") {
            if vm.outboxChallenges.isEmpty {
                Card {
                    Text("送信したチャレンジはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.outboxChallenges, id: \.id) { ev in
                    NavigationLink {
                        ThreadView(
                            challenge: ev,
                            vm: vm,
                            shareItems: { items in
                                shareSheetItems = items
                                isPresentingShareSheet = true
                            }
                        )
                    } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ev.link.prompt)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text("dateKey: \(ev.link.dateKey)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    if let room = ev.link.room { Text("room: \(room)") }
                                    if let chain = ev.link.chainId { Text("chain: \(chain)") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var commentsInboxSection: some View {
        Section("Inbox - Comments") {
            if vm.inboxComments.isEmpty {
                Card {
                    Text("受信したコメントはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxComments, id: \.id) { ev in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ev.link.text)
                                .font(.headline)
                                .lineLimit(3)
                            Text("from: \(ev.link.fromName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        moderationContextMenu(userId: ev.link.fromId, name: ev.link.fromName, source: "comment_inbox")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var commentsOutboxSection: some View {
        Section("Outbox - Comments") {
            if vm.outboxComments.isEmpty {
                Card {
                    Text("送信したコメントはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.outboxComments, id: \.id) { ev in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ev.link.text)
                                .font(.headline)
                                .lineLimit(3)
                            if let room = ev.link.room {
                                Text("room: \(room)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var reactionsInboxSection: some View {
        Section("Inbox - Reactions") {
            if vm.inboxReactions.isEmpty {
                Card {
                    Text("受信したリアクションはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.inboxReactions, id: \.id) { ev in
                    Card {
                        Text("\(ev.link.emoji)   from: \(ev.link.fromName)")
                            .font(.headline)
                    }
                    .contextMenu {
                        moderationContextMenu(userId: ev.link.fromId, name: ev.link.fromName, source: "reaction_inbox")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var reactionsOutboxSection: some View {
        Section("Outbox - Reactions") {
            if vm.outboxReactions.isEmpty {
                Card {
                    Text("送信したリアクションはありません")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.outboxReactions, id: \.id) { ev in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(ev.link.emoji)   sent")
                                .font(.headline)
                            if let to = ev.link.toChallengeId {
                                Text("toChallengeId: \(to)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}

// MARK: - Background

private struct CommunityGradientBackground: View {
    @Environment(\.currentDecorationId) private var decorationId
    private var style: DecorationStyle { DecorationStyle.from(decorationId) }

    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.90),
                Color(.secondarySystemBackground).opacity(0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: style.tintColors,
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        )
    }

    private enum DecorationStyle: String, CaseIterable {
        case classic, sakura, aurora, neon, gold
        static func from(_ raw: String) -> DecorationStyle {
            let resolved = DecorationThemeResolver.resolveStyleID(
                from: raw,
                supportedStyleIDs: Set(Self.allCases.map(\.rawValue))
            )
            return DecorationStyle(rawValue: resolved) ?? .classic
        }

        var tintColors: [Color] {
            switch self {
            case .classic: return [Color.purple.opacity(0.08), Color.blue.opacity(0.06), Color.clear]
            case .sakura:  return [Color.pink.opacity(0.10),   Color.purple.opacity(0.05), Color.clear]
            case .aurora:  return [Color.green.opacity(0.08),  Color.blue.opacity(0.08),   Color.clear]
            case .neon:    return [Color.cyan.opacity(0.08),   Color.purple.opacity(0.06), Color.clear]
            case .gold:    return [Color.yellow.opacity(0.08), Color.orange.opacity(0.06), Color.clear]
            }
        }
    }
}
