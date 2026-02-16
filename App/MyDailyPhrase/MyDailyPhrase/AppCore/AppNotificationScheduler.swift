import Foundation
import UserNotifications

@MainActor
final class AppNotificationScheduler {
    private typealias NotificationCampaign = AppNotificationSettings.NotificationCampaign
    private typealias NotificationVariant = AppNotificationSettings.NotificationVariant
    private typealias NotificationTimeBlock = AppNotificationSettings.NotificationTimeBlock
    private typealias NotificationTimingSlot = AppNotificationSettings.NotificationTimingSlot
    private typealias TrackedDispatch = AppNotificationSettings.TrackedDispatch

    private enum Identifier {
        static let promptUpdate = "MyDailyPhrase.notification.promptUpdate"
        static let streakReminder = "MyDailyPhrase.notification.streakReminder"
        static let missionReady = "MyDailyPhrase.notification.missionReady"
        static let weeklyTrend = "MyDailyPhrase.notification.weeklyTrend"
        static let seasonMilestoneReady = "MyDailyPhrase.notification.seasonMilestoneReady"
        static let seasonMilestoneReminder = "MyDailyPhrase.notification.seasonMilestoneReminder"
    }

    private enum PayloadKey {
        static let tracked = "mdpTracked"
        static let campaign = "mdpCampaign"
        static let variant = "mdpVariant"
        static let dispatchID = "mdpDispatchID"
        static let sentAt = "mdpSentAt"
        static let contextKey = "mdpContextKey"
        static let timingSlot = "mdpTimingSlot"
    }

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let optimizationMinimumSamples = 8
    private let contextOptimizationMinimumSamples = 6
    private let optimizationExplorationRate = 0.18
    private let timingOptimizationExplorationRate = 0.22
    private let timingOptimizationMinimumSamples = 10
    private let returnDetectionWindow: TimeInterval = 24 * 60 * 60
    private let minimumReturnLag: TimeInterval = 60
    private let trackedDispatchRetention: TimeInterval = 72 * 60 * 60

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults
    ) {
        self.center = center
        self.defaults = defaults
    }

    func rescheduleRecurringNotifications(
        promptText: String,
        isAnsweredToday: Bool,
        streakDays: Int
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [
            Identifier.promptUpdate,
            Identifier.streakReminder
        ])

        let prefs = AppNotificationSettings.load(from: defaults)
        guard prefs.isEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [
                Identifier.weeklyTrend,
                Identifier.seasonMilestoneReady,
                Identifier.seasonMilestoneReminder
            ])
            return
        }

        if prefs.promptUpdateEnabled {
            schedulePromptUpdateNotification(promptText: promptText)
        }

        if prefs.streakReminderEnabled {
            scheduleStreakReminderIfNeeded(isAnsweredToday: isAnsweredToday, streakDays: streakDays)
        }

        if !prefs.weeklyTrendEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [Identifier.weeklyTrend])
        }
    }

    func handleSeasonMilestoneUpdate(
        weekKey: String,
        themeTitle: String,
        currentOwnedCount: Int,
        hasClaimableReward: Bool,
        nextRemainingCount: Int?
    ) {
        let prefs = AppNotificationSettings.load(from: defaults)
        guard prefs.isEnabled, prefs.missionEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [
                Identifier.seasonMilestoneReady,
                Identifier.seasonMilestoneReminder
            ])
            return
        }

        let now = Date()
        let weekday = weekdayIndex(for: now)
        let reminderTimingSlot = optimizedReminderTimingSlot(weekday: weekday)
        let readyContextKey = makeContextKey(for: now, timingSlot: nil)
        let reminderContextKey = makeContextKey(for: now, timingSlot: reminderTimingSlot)

        let readyVariant = optimizedVariant(for: .seasonMilestoneReady, contextKey: readyContextKey)
        let reminderVariant = optimizedVariant(for: .seasonMilestoneReminder, contextKey: reminderContextKey)
        defaults.set(readyVariant.rawValue, forKey: AppNotificationSettings.seasonMilestoneReadyCopyVariantKey)
        defaults.set(reminderVariant.rawValue, forKey: AppNotificationSettings.seasonMilestoneReminderCopyVariantKey)

        let todayKey = Self.dateKey(for: now)
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.seasonMilestoneReminder])

        if hasClaimableReward {
            let digest = "\(weekKey)|\(themeTitle)|\(currentOwnedCount)|\(readyVariant.rawValue)"
            let lastDigest = defaults.string(forKey: AppNotificationSettings.lastSeasonMilestoneReadyDigestKey)
            let lastDate = defaults.string(forKey: AppNotificationSettings.lastSeasonMilestoneReadyDateKey)
            guard !(lastDigest == digest && lastDate == todayKey) else { return }

            let dispatchID = UUID().uuidString
            let copy = seasonMilestoneReadyCopy(themeTitle: themeTitle, variant: readyVariant)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = trackedUserInfo(
                campaign: .seasonMilestoneReady,
                variant: readyVariant,
                dispatchID: dispatchID,
                sentAt: now,
                contextKey: readyContextKey,
                timingSlot: nil
            )

            let request = UNNotificationRequest(
                identifier: Identifier.seasonMilestoneReady,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            )
            center.add(request)
            registerDispatch(
                campaign: .seasonMilestoneReady,
                variant: readyVariant,
                dispatchID: dispatchID,
                sentAt: now,
                contextKey: readyContextKey,
                timingSlot: nil
            )
            defaults.set(digest, forKey: AppNotificationSettings.lastSeasonMilestoneReadyDigestKey)
            defaults.set(todayKey, forKey: AppNotificationSettings.lastSeasonMilestoneReadyDateKey)
            return
        }

        guard let nextRemainingCount, nextRemainingCount > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [Identifier.seasonMilestoneReminder])
            return
        }
        let remain = max(1, nextRemainingCount)
        let lastReminderDate = defaults.string(forKey: AppNotificationSettings.lastSeasonMilestoneReminderDateKey)
        let lastReminderWeek = defaults.string(forKey: AppNotificationSettings.lastSeasonMilestoneReminderWeekKey)
        guard !(lastReminderDate == todayKey && lastReminderWeek == weekKey) else { return }

        let targetDate = reminderTargetDate(for: reminderTimingSlot, now: now)

        let dispatchID = UUID().uuidString
        let copy = seasonMilestoneReminderCopy(
            themeTitle: themeTitle,
            remainingCount: remain,
            variant: reminderVariant
        )
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.userInfo = trackedUserInfo(
            campaign: .seasonMilestoneReminder,
            variant: reminderVariant,
            dispatchID: dispatchID,
            sentAt: now,
            contextKey: reminderContextKey,
            timingSlot: reminderTimingSlot
        )

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, targetDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Identifier.seasonMilestoneReminder,
            content: content,
            trigger: trigger
        )
        center.add(request)
        registerDispatch(
            campaign: .seasonMilestoneReminder,
            variant: reminderVariant,
            dispatchID: dispatchID,
            sentAt: now,
            contextKey: reminderContextKey,
            timingSlot: reminderTimingSlot
        )
        defaults.set(todayKey, forKey: AppNotificationSettings.lastSeasonMilestoneReminderDateKey)
        defaults.set(weekKey, forKey: AppNotificationSettings.lastSeasonMilestoneReminderWeekKey)
    }

    func handleShareMissionUpdate(canClaimReward: Bool) {
        let prefs = AppNotificationSettings.load(from: defaults)
        guard prefs.isEnabled, prefs.missionEnabled, canClaimReward else { return }

        let todayKey = Self.dateKey(for: Date())
        let lastNotified = defaults.string(forKey: AppNotificationSettings.lastMissionNotifiedDateKey)
        guard lastNotified != todayKey else { return }

        let content = UNMutableNotificationContent()
        content.title = "シェアミッション達成"
        content.body = "報酬チケットを受け取りましょう。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Identifier.missionReady,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )
        center.add(request)
        defaults.set(todayKey, forKey: AppNotificationSettings.lastMissionNotifiedDateKey)
    }

    func handleWeeklyTrendUpdate(
        prompt: String,
        engagementScore: Int,
        postCount: Int,
        reactionCount: Int
    ) {
        let prefs = AppNotificationSettings.load(from: defaults)
        guard prefs.isEnabled, prefs.weeklyTrendEnabled else { return }

        // Creator Pass限定通知。購読が切れている場合は通知しない。
        guard defaults.bool(forKey: IAPStore.creatorPassEntitlementKey) else { return }

        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else { return }

        let digest = Self.makeWeeklyTrendDigest(
            prompt: normalizedPrompt,
            engagementScore: engagementScore,
            postCount: postCount,
            reactionCount: reactionCount
        )
        let todayKey = Self.dateKey(for: Date())
        let lastDigest = defaults.string(forKey: AppNotificationSettings.lastWeeklyTrendDigestKey)
        let lastNotifiedDate = defaults.string(forKey: AppNotificationSettings.lastWeeklyTrendNotifiedDateKey)

        if lastDigest == digest, lastNotifiedDate == todayKey {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "今週急上昇のお題"
        content.body = "\(normalizedPrompt)（投稿\(postCount)・👍\(reactionCount)）"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Identifier.weeklyTrend,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.weeklyTrend])
        center.add(request)
        defaults.set(digest, forKey: AppNotificationSettings.lastWeeklyTrendDigestKey)
        defaults.set(todayKey, forKey: AppNotificationSettings.lastWeeklyTrendNotifiedDateKey)
    }

    func recordNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard let tracked = trackedPayload(from: userInfo) else { return }

        var dispatches = AppNotificationSettings.loadTrackedDispatches(from: defaults)
        let now = Date()
        var changed = false

        if let index = dispatches.firstIndex(where: { $0.id == tracked.dispatchID }) {
            var dispatch = dispatches[index]
            if !dispatch.opened {
                dispatch.opened = true
                incrementCampaignOpened(
                    campaign: dispatch.campaign,
                    variant: dispatch.variant,
                    contextKey: dispatch.contextKey
                )
                if dispatch.campaign == .seasonMilestoneReminder,
                   let slot = dispatch.timingSlot {
                    incrementReminderTimingOpened(slot: slot, weekday: weekdayIndex(for: dispatch.sentAt))
                }
                changed = true
            }
            if !dispatch.returned {
                dispatch.returned = true
                incrementCampaignReturned(
                    campaign: dispatch.campaign,
                    variant: dispatch.variant,
                    contextKey: dispatch.contextKey
                )
                if dispatch.campaign == .seasonMilestoneReminder,
                   let slot = dispatch.timingSlot {
                    incrementReminderTimingReturned(slot: slot, weekday: weekdayIndex(for: dispatch.sentAt))
                }
                changed = true
            }
            dispatches[index] = dispatch
        } else {
            // Dispatch metadata might have been pruned, but response can still be counted once.
            incrementCampaignOpened(
                campaign: tracked.campaign,
                variant: tracked.variant,
                contextKey: tracked.contextKey
            )
            incrementCampaignReturned(
                campaign: tracked.campaign,
                variant: tracked.variant,
                contextKey: tracked.contextKey
            )
            if tracked.campaign == .seasonMilestoneReminder,
               let slot = tracked.timingSlot {
                let weekday = weekdayIndex(for: tracked.sentAt)
                incrementReminderTimingOpened(slot: slot, weekday: weekday)
                incrementReminderTimingReturned(slot: slot, weekday: weekday)
            }
            dispatches.append(
                TrackedDispatch(
                    id: tracked.dispatchID,
                    campaign: tracked.campaign,
                    variant: tracked.variant,
                    sentAt: tracked.sentAt,
                    opened: true,
                    returned: true,
                    contextKey: tracked.contextKey,
                    timingSlot: tracked.timingSlot
                )
            )
            changed = true
        }

        dispatches = normalizeDispatches(dispatches, now: now)
        AppNotificationSettings.saveTrackedDispatches(dispatches, to: defaults)
        defaults.set(now, forKey: AppNotificationSettings.lastAppForegroundAtKey)
        if changed {
            postMetricsDidUpdate()
        }
    }

    func recordAppForeground(now: Date = Date()) {
        let previousForeground = defaults.object(forKey: AppNotificationSettings.lastAppForegroundAtKey) as? Date
        var dispatches = AppNotificationSettings.loadTrackedDispatches(from: defaults)
        let originalCount = dispatches.count
        var updated = false

        if let previousForeground {
            for index in dispatches.indices {
                var dispatch = dispatches[index]
                if dispatch.returned { continue }
                let elapsed = now.timeIntervalSince(dispatch.sentAt)
                guard elapsed >= minimumReturnLag, elapsed <= returnDetectionWindow else { continue }
                guard previousForeground < dispatch.sentAt else { continue }

                dispatch.returned = true
                dispatches[index] = dispatch
                incrementCampaignReturned(
                    campaign: dispatch.campaign,
                    variant: dispatch.variant,
                    contextKey: dispatch.contextKey
                )
                if dispatch.campaign == .seasonMilestoneReminder,
                   let slot = dispatch.timingSlot {
                    incrementReminderTimingReturned(slot: slot, weekday: weekdayIndex(for: dispatch.sentAt))
                }
                updated = true
            }
        }

        dispatches = normalizeDispatches(dispatches, now: now)
        let pruned = dispatches.count != originalCount
        if updated || pruned {
            AppNotificationSettings.saveTrackedDispatches(dispatches, to: defaults)
            postMetricsDidUpdate()
        }
        defaults.set(now, forKey: AppNotificationSettings.lastAppForegroundAtKey)
    }

    private func schedulePromptUpdateNotification(promptText: String) {
        let content = UNMutableNotificationContent()
        content.title = "今日のお題が更新されました"
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = trimmedPrompt.isEmpty ? "MyDailyPhraseを開いて、今日の内省を始めましょう。" : trimmedPrompt
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Identifier.promptUpdate, content: content, trigger: trigger)
        center.add(request)
    }

    private func scheduleStreakReminderIfNeeded(isAnsweredToday: Bool, streakDays: Int) {
        guard !isAnsweredToday, streakDays > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "連続記録をキープしよう"
        content.body = "あと1分で、\(streakDays)日連続を維持できます。"
        content.sound = .default

        let now = Date()
        let calendar = Calendar.current
        let todayReminder = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)
        let targetDate: Date
        if let todayReminder, todayReminder > now {
            targetDate = todayReminder
        } else {
            targetDate = now.addingTimeInterval(60)
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, targetDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: Identifier.streakReminder, content: content, trigger: trigger)
        center.add(request)
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func makeWeeklyTrendDigest(
        prompt: String,
        engagementScore: Int,
        postCount: Int,
        reactionCount: Int
    ) -> String {
        "\(prompt)|\(engagementScore)|\(postCount)|\(reactionCount)"
    }

    private func optimizedVariant(for campaign: NotificationCampaign, contextKey: String?) -> NotificationVariant {
        let globalStats = AppNotificationSettings.loadCampaignStats(for: campaign, from: defaults)
        let contextStats: AppNotificationSettings.NotificationCampaignStats = {
            guard let contextKey else { return .empty }
            let map = AppNotificationSettings.loadCampaignContextStats(for: campaign, from: defaults)
            return map[contextKey] ?? .empty
        }()

        let effectiveStats: AppNotificationSettings.NotificationCampaignStats
        if contextStats.totalSent >= contextOptimizationMinimumSamples {
            effectiveStats = contextStats
        } else {
            effectiveStats = globalStats
        }

        let shouldBalanceBySent = effectiveStats.a.sent < optimizationMinimumSamples || effectiveStats.b.sent < optimizationMinimumSamples
        if shouldBalanceBySent {
            return effectiveStats.a.sent <= effectiveStats.b.sent ? .a : .b
        }

        if Double.random(in: 0 ... 1) < optimizationExplorationRate {
            return Bool.random() ? .a : .b
        }

        return AppNotificationSettings.recommendedVariant(for: effectiveStats)
    }

    private func optimizedReminderTimingSlot(weekday: Int) -> NotificationTimingSlot {
        let global = AppNotificationSettings.loadReminderTimingStats(from: defaults)
        let weekdayMap = AppNotificationSettings.loadReminderTimingStatsByWeekday(from: defaults)
        let weekdayStats = weekdayMap["\(weekday)"] ?? .empty

        let effectiveStats = weekdayStats.totalSent >= timingOptimizationMinimumSamples ? weekdayStats : global

        if Double.random(in: 0 ... 1) < timingOptimizationExplorationRate {
            let balanced = NotificationTimingSlot.allCases.sorted { lhs, rhs in
                effectiveStats.stats(for: lhs).sent < effectiveStats.stats(for: rhs).sent
            }
            return balanced.first ?? .primeTime
        }

        return AppNotificationSettings.recommendedTimingSlot(for: effectiveStats)
    }

    private func registerDispatch(
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        dispatchID: String,
        sentAt: Date,
        contextKey: String?,
        timingSlot: NotificationTimingSlot?
    ) {
        incrementCampaignSent(campaign: campaign, variant: variant, contextKey: contextKey)
        if campaign == .seasonMilestoneReminder, let timingSlot {
            incrementReminderTimingSent(slot: timingSlot, weekday: weekdayIndex(for: sentAt))
        }

        var dispatches = AppNotificationSettings.loadTrackedDispatches(from: defaults)
        dispatches.append(
            TrackedDispatch(
                id: dispatchID,
                campaign: campaign,
                variant: variant,
                sentAt: sentAt,
                opened: false,
                returned: false,
                contextKey: contextKey,
                timingSlot: timingSlot
            )
        )
        dispatches = normalizeDispatches(dispatches, now: sentAt)
        AppNotificationSettings.saveTrackedDispatches(dispatches, to: defaults)
        postMetricsDidUpdate()
    }

    private func trackedUserInfo(
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        dispatchID: String,
        sentAt: Date,
        contextKey: String?,
        timingSlot: NotificationTimingSlot?
    ) -> [AnyHashable: Any] {
        var payload: [AnyHashable: Any] = [
            PayloadKey.tracked: true,
            PayloadKey.campaign: campaign.rawValue,
            PayloadKey.variant: variant.rawValue,
            PayloadKey.dispatchID: dispatchID,
            PayloadKey.sentAt: sentAt.timeIntervalSince1970
        ]
        if let contextKey {
            payload[PayloadKey.contextKey] = contextKey
        }
        if let timingSlot {
            payload[PayloadKey.timingSlot] = timingSlot.rawValue
        }
        return payload
    }

    private func trackedPayload(
        from userInfo: [AnyHashable: Any]
    ) -> (
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        dispatchID: String,
        sentAt: Date,
        contextKey: String?,
        timingSlot: NotificationTimingSlot?
    )? {
        guard (userInfo[PayloadKey.tracked] as? Bool) == true,
              let campaignRaw = userInfo[PayloadKey.campaign] as? String,
              let campaign = NotificationCampaign(rawValue: campaignRaw),
              let variantRaw = userInfo[PayloadKey.variant] as? String,
              let variant = NotificationVariant(rawValue: variantRaw),
              let dispatchID = userInfo[PayloadKey.dispatchID] as? String else {
            return nil
        }

        let sentAtValue = userInfo[PayloadKey.sentAt]
        let sentAtTimestamp: TimeInterval
        switch sentAtValue {
        case let value as Double:
            sentAtTimestamp = value
        case let value as NSNumber:
            sentAtTimestamp = value.doubleValue
        default:
            sentAtTimestamp = Date().timeIntervalSince1970
        }
        let contextKey = userInfo[PayloadKey.contextKey] as? String
        let timingSlot = (userInfo[PayloadKey.timingSlot] as? String).flatMap(NotificationTimingSlot.init(rawValue:))

        return (
            campaign: campaign,
            variant: variant,
            dispatchID: dispatchID,
            sentAt: Date(timeIntervalSince1970: sentAtTimestamp),
            contextKey: contextKey,
            timingSlot: timingSlot
        )
    }

    private func normalizeDispatches(_ dispatches: [TrackedDispatch], now: Date) -> [TrackedDispatch] {
        let cutoff = now.addingTimeInterval(-trackedDispatchRetention)
        var seen: Set<String> = []
        var normalized: [TrackedDispatch] = []

        for dispatch in dispatches.sorted(by: { $0.sentAt > $1.sentAt }) {
            guard dispatch.sentAt >= cutoff else { continue }
            guard !seen.contains(dispatch.id) else { continue }
            seen.insert(dispatch.id)
            normalized.append(dispatch)
        }

        return normalized.sorted(by: { $0.sentAt < $1.sentAt })
    }

    private func incrementCampaignSent(
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        contextKey: String?
    ) {
        var global = AppNotificationSettings.loadCampaignStats(for: campaign, from: defaults)
        global.incrementSent(for: variant)
        AppNotificationSettings.saveCampaignStats(global, for: campaign, to: defaults)

        guard let contextKey else { return }
        var contextMap = AppNotificationSettings.loadCampaignContextStats(for: campaign, from: defaults)
        var context = contextMap[contextKey] ?? .empty
        context.incrementSent(for: variant)
        contextMap[contextKey] = context
        AppNotificationSettings.saveCampaignContextStats(contextMap, for: campaign, to: defaults)
    }

    private func incrementCampaignOpened(
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        contextKey: String?
    ) {
        var global = AppNotificationSettings.loadCampaignStats(for: campaign, from: defaults)
        global.incrementOpened(for: variant)
        AppNotificationSettings.saveCampaignStats(global, for: campaign, to: defaults)

        guard let contextKey else { return }
        var contextMap = AppNotificationSettings.loadCampaignContextStats(for: campaign, from: defaults)
        var context = contextMap[contextKey] ?? .empty
        context.incrementOpened(for: variant)
        contextMap[contextKey] = context
        AppNotificationSettings.saveCampaignContextStats(contextMap, for: campaign, to: defaults)
    }

    private func incrementCampaignReturned(
        campaign: NotificationCampaign,
        variant: NotificationVariant,
        contextKey: String?
    ) {
        var global = AppNotificationSettings.loadCampaignStats(for: campaign, from: defaults)
        global.incrementReturned(for: variant)
        AppNotificationSettings.saveCampaignStats(global, for: campaign, to: defaults)

        guard let contextKey else { return }
        var contextMap = AppNotificationSettings.loadCampaignContextStats(for: campaign, from: defaults)
        var context = contextMap[contextKey] ?? .empty
        context.incrementReturned(for: variant)
        contextMap[contextKey] = context
        AppNotificationSettings.saveCampaignContextStats(contextMap, for: campaign, to: defaults)
    }

    private func incrementReminderTimingSent(slot: NotificationTimingSlot, weekday: Int) {
        incrementReminderTiming(slot: slot, weekday: weekday, kind: .sent)
    }

    private func incrementReminderTimingOpened(slot: NotificationTimingSlot, weekday: Int) {
        incrementReminderTiming(slot: slot, weekday: weekday, kind: .opened)
    }

    private func incrementReminderTimingReturned(slot: NotificationTimingSlot, weekday: Int) {
        incrementReminderTiming(slot: slot, weekday: weekday, kind: .returned)
    }

    private enum TimingMetricKind {
        case sent
        case opened
        case returned
    }

    private func incrementReminderTiming(
        slot: NotificationTimingSlot,
        weekday: Int,
        kind: TimingMetricKind
    ) {
        var global = AppNotificationSettings.loadReminderTimingStats(from: defaults)
        switch kind {
        case .sent:
            global.incrementSent(for: slot)
        case .opened:
            global.incrementOpened(for: slot)
        case .returned:
            global.incrementReturned(for: slot)
        }
        AppNotificationSettings.saveReminderTimingStats(global, to: defaults)

        var byWeekday = AppNotificationSettings.loadReminderTimingStatsByWeekday(from: defaults)
        let key = "\(weekday)"
        var weekdayStats = byWeekday[key] ?? .empty
        switch kind {
        case .sent:
            weekdayStats.incrementSent(for: slot)
        case .opened:
            weekdayStats.incrementOpened(for: slot)
        case .returned:
            weekdayStats.incrementReturned(for: slot)
        }
        byWeekday[key] = weekdayStats
        AppNotificationSettings.saveReminderTimingStatsByWeekday(byWeekday, to: defaults)
    }

    private func reminderTargetDate(for slot: NotificationTimingSlot, now: Date) -> Date {
        let calendar = Calendar.current
        let preferred = calendar.date(
            bySettingHour: slot.hour,
            minute: slot.minute,
            second: 0,
            of: now
        )
        if let preferred, preferred > now {
            return preferred
        }
        return now.addingTimeInterval(90 * 60)
    }

    private func weekdayIndex(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date)
    }

    private func makeContextKey(for date: Date, timingSlot: NotificationTimingSlot?) -> String {
        let weekday = weekdayIndex(for: date)
        if let timingSlot {
            return "w\(weekday)_slot_\(timingSlot.rawValue)"
        }
        let block = timeBlock(for: date)
        return "w\(weekday)_\(block.rawValue)"
    }

    private func timeBlock(for date: Date) -> NotificationTimeBlock {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5...10:
            return .morning
        case 11...16:
            return .daytime
        case 17...21:
            return .evening
        default:
            return .night
        }
    }

    private func postMetricsDidUpdate() {
        NotificationCenter.default.post(name: .notificationABMetricsDidUpdate, object: nil)
    }

    private func seasonMilestoneReadyCopy(
        themeTitle: String,
        variant: NotificationVariant
    ) -> (title: String, body: String) {
        switch variant {
        case .a:
            return (
                title: "シーズン報酬を受け取れます",
                body: "今週の\(themeTitle)テーマの報酬が解放されました。"
            )
        case .b:
            return (
                title: "限定報酬が解放されました",
                body: "\(themeTitle)テーマの報酬を受け取って、進捗を次へ進めましょう。"
            )
        }
    }

    private func seasonMilestoneReminderCopy(
        themeTitle: String,
        remainingCount: Int,
        variant: NotificationVariant
    ) -> (title: String, body: String) {
        switch variant {
        case .a:
            return (
                title: "シーズンミッション進行中",
                body: "\(themeTitle)テーマは、あと\(remainingCount)個で次の報酬です。"
            )
        case .b:
            return (
                title: "あと\(remainingCount)個で報酬解放",
                body: "\(themeTitle)テーマをもう少し進めて、今週の報酬を受け取りましょう。"
            )
        }
    }
}
