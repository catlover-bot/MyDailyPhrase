import Foundation

enum AppNotificationSettings {
    static let enabledKey = "MyDailyPhrase.notifications.enabled.v1"
    static let promptUpdateEnabledKey = "MyDailyPhrase.notifications.promptUpdate.enabled.v1"
    static let missionEnabledKey = "MyDailyPhrase.notifications.mission.enabled.v1"
    static let streakReminderEnabledKey = "MyDailyPhrase.notifications.streakReminder.enabled.v1"
    static let weeklyTrendEnabledKey = "MyDailyPhrase.notifications.weeklyTrend.enabled.v1"
    static let lastMissionNotifiedDateKey = "MyDailyPhrase.notifications.lastMissionNotifiedDate.v1"
    static let lastWeeklyTrendDigestKey = "MyDailyPhrase.notifications.lastWeeklyTrendDigest.v1"
    static let lastWeeklyTrendNotifiedDateKey = "MyDailyPhrase.notifications.lastWeeklyTrendNotifiedDate.v1"
    static let lastSeasonMilestoneReadyDigestKey = "MyDailyPhrase.notifications.lastSeasonMilestoneReadyDigest.v1"
    static let lastSeasonMilestoneReadyDateKey = "MyDailyPhrase.notifications.lastSeasonMilestoneReadyDate.v1"
    static let lastSeasonMilestoneReminderDateKey = "MyDailyPhrase.notifications.lastSeasonMilestoneReminderDate.v1"
    static let lastSeasonMilestoneReminderWeekKey = "MyDailyPhrase.notifications.lastSeasonMilestoneReminderWeek.v1"
    static let seasonMilestoneReadyCopyVariantKey = "MyDailyPhrase.notifications.seasonMilestoneReadyCopyVariant.v1"
    static let seasonMilestoneReminderCopyVariantKey = "MyDailyPhrase.notifications.seasonMilestoneReminderCopyVariant.v1"
    static let seasonMilestoneReadyABStatsKey = "MyDailyPhrase.notifications.seasonMilestoneReadyABStats.v1"
    static let seasonMilestoneReminderABStatsKey = "MyDailyPhrase.notifications.seasonMilestoneReminderABStats.v1"
    static let seasonMilestoneReadyABStatsByContextKey = "MyDailyPhrase.notifications.seasonMilestoneReadyABStats.byContext.v1"
    static let seasonMilestoneReminderABStatsByContextKey = "MyDailyPhrase.notifications.seasonMilestoneReminderABStats.byContext.v1"
    static let seasonMilestoneReminderTimingStatsKey = "MyDailyPhrase.notifications.seasonMilestoneReminderTimingStats.v1"
    static let seasonMilestoneReminderTimingStatsByWeekdayKey = "MyDailyPhrase.notifications.seasonMilestoneReminderTimingStats.byWeekday.v1"
    static let trackedDispatchesKey = "MyDailyPhrase.notifications.trackedDispatches.v1"
    static let lastAppForegroundAtKey = "MyDailyPhrase.notifications.lastAppForegroundAt.v1"

    enum NotificationCampaign: String, Codable, CaseIterable, Sendable {
        case seasonMilestoneReady
        case seasonMilestoneReminder

        var title: String {
            switch self {
            case .seasonMilestoneReady:
                return "報酬解放通知"
            case .seasonMilestoneReminder:
                return "収集中リマインド"
            }
        }
    }

    enum NotificationVariant: String, Codable, CaseIterable, Sendable {
        case a
        case b

        var label: String {
            rawValue.uppercased()
        }
    }

    enum NotificationTimeBlock: String, Codable, CaseIterable, Sendable {
        case morning
        case daytime
        case evening
        case night
    }

    enum NotificationTimingSlot: String, Codable, CaseIterable, Sendable {
        case earlyEvening
        case primeTime
        case lateNight

        var hour: Int {
            switch self {
            case .earlyEvening:
                return 18
            case .primeTime:
                return 20
            case .lateNight:
                return 22
            }
        }

        var minute: Int {
            switch self {
            case .earlyEvening:
                return 30
            case .primeTime:
                return 30
            case .lateNight:
                return 0
            }
        }

        var label: String {
            switch self {
            case .earlyEvening:
                return "18:30"
            case .primeTime:
                return "20:30"
            case .lateNight:
                return "22:00"
            }
        }
    }

    struct NotificationVariantStats: Codable, Equatable, Sendable {
        var sent: Int
        var opened: Int
        var returned: Int

        static let empty = NotificationVariantStats(sent: 0, opened: 0, returned: 0)

        var openRate: Double {
            guard sent > 0 else { return 0 }
            return Double(opened) / Double(sent)
        }

        var returnRate: Double {
            guard sent > 0 else { return 0 }
            return Double(returned) / Double(sent)
        }

        var weightedScore: Double {
            // Open rate is primary KPI. Return rate is secondary.
            (openRate * 0.70) + (returnRate * 0.30)
        }

        mutating func incrementSent() {
            sent += 1
        }

        mutating func incrementOpened() {
            opened += 1
        }

        mutating func incrementReturned() {
            returned += 1
        }
    }

    struct NotificationCampaignStats: Codable, Equatable, Sendable {
        var a: NotificationVariantStats
        var b: NotificationVariantStats

        static let empty = NotificationCampaignStats(
            a: .empty,
            b: .empty
        )

        var totalSent: Int { a.sent + b.sent }

        func stats(for variant: NotificationVariant) -> NotificationVariantStats {
            switch variant {
            case .a: return a
            case .b: return b
            }
        }

        mutating func incrementSent(for variant: NotificationVariant) {
            switch variant {
            case .a:
                a.incrementSent()
            case .b:
                b.incrementSent()
            }
        }

        mutating func incrementOpened(for variant: NotificationVariant) {
            switch variant {
            case .a:
                a.incrementOpened()
            case .b:
                b.incrementOpened()
            }
        }

        mutating func incrementReturned(for variant: NotificationVariant) {
            switch variant {
            case .a:
                a.incrementReturned()
            case .b:
                b.incrementReturned()
            }
        }
    }

    struct NotificationTimingSlotStats: Codable, Equatable, Sendable {
        var sent: Int
        var opened: Int
        var returned: Int

        static let empty = NotificationTimingSlotStats(sent: 0, opened: 0, returned: 0)

        var openRate: Double {
            guard sent > 0 else { return 0 }
            return Double(opened) / Double(sent)
        }

        var returnRate: Double {
            guard sent > 0 else { return 0 }
            return Double(returned) / Double(sent)
        }

        var weightedScore: Double {
            (openRate * 0.70) + (returnRate * 0.30)
        }

        mutating func incrementSent() {
            sent += 1
        }

        mutating func incrementOpened() {
            opened += 1
        }

        mutating func incrementReturned() {
            returned += 1
        }
    }

    struct NotificationTimingStats: Codable, Equatable, Sendable {
        var earlyEvening: NotificationTimingSlotStats
        var primeTime: NotificationTimingSlotStats
        var lateNight: NotificationTimingSlotStats

        static let empty = NotificationTimingStats(
            earlyEvening: .empty,
            primeTime: .empty,
            lateNight: .empty
        )

        var totalSent: Int {
            earlyEvening.sent + primeTime.sent + lateNight.sent
        }

        func stats(for slot: NotificationTimingSlot) -> NotificationTimingSlotStats {
            switch slot {
            case .earlyEvening:
                return earlyEvening
            case .primeTime:
                return primeTime
            case .lateNight:
                return lateNight
            }
        }

        mutating func incrementSent(for slot: NotificationTimingSlot) {
            switch slot {
            case .earlyEvening:
                earlyEvening.incrementSent()
            case .primeTime:
                primeTime.incrementSent()
            case .lateNight:
                lateNight.incrementSent()
            }
        }

        mutating func incrementOpened(for slot: NotificationTimingSlot) {
            switch slot {
            case .earlyEvening:
                earlyEvening.incrementOpened()
            case .primeTime:
                primeTime.incrementOpened()
            case .lateNight:
                lateNight.incrementOpened()
            }
        }

        mutating func incrementReturned(for slot: NotificationTimingSlot) {
            switch slot {
            case .earlyEvening:
                earlyEvening.incrementReturned()
            case .primeTime:
                primeTime.incrementReturned()
            case .lateNight:
                lateNight.incrementReturned()
            }
        }
    }

    struct TrackedDispatch: Codable, Equatable, Sendable {
        var id: String
        var campaign: NotificationCampaign
        var variant: NotificationVariant
        var sentAt: Date
        var opened: Bool
        var returned: Bool
        var contextKey: String?
        var timingSlot: NotificationTimingSlot?
    }

    struct Preferences: Equatable, Sendable {
        var isEnabled: Bool
        var promptUpdateEnabled: Bool
        var missionEnabled: Bool
        var streakReminderEnabled: Bool
        var weeklyTrendEnabled: Bool

        static let `default` = Preferences(
            isEnabled: false,
            promptUpdateEnabled: true,
            missionEnabled: true,
            streakReminderEnabled: true,
            weeklyTrendEnabled: true
        )
    }

    static func load(from defaults: UserDefaults) -> Preferences {
        let hasAnyStoredValue =
            defaults.object(forKey: enabledKey) != nil
            || defaults.object(forKey: promptUpdateEnabledKey) != nil
            || defaults.object(forKey: missionEnabledKey) != nil
            || defaults.object(forKey: streakReminderEnabledKey) != nil
            || defaults.object(forKey: weeklyTrendEnabledKey) != nil

        guard hasAnyStoredValue else { return .default }

        return Preferences(
            isEnabled: defaults.bool(forKey: enabledKey),
            promptUpdateEnabled: defaults.bool(forKey: promptUpdateEnabledKey),
            missionEnabled: defaults.bool(forKey: missionEnabledKey),
            streakReminderEnabled: defaults.bool(forKey: streakReminderEnabledKey),
            weeklyTrendEnabled: defaults.object(forKey: weeklyTrendEnabledKey) == nil
                ? Preferences.default.weeklyTrendEnabled
                : defaults.bool(forKey: weeklyTrendEnabledKey)
        )
    }

    static func save(_ preferences: Preferences, to defaults: UserDefaults) {
        defaults.set(preferences.isEnabled, forKey: enabledKey)
        defaults.set(preferences.promptUpdateEnabled, forKey: promptUpdateEnabledKey)
        defaults.set(preferences.missionEnabled, forKey: missionEnabledKey)
        defaults.set(preferences.streakReminderEnabled, forKey: streakReminderEnabledKey)
        defaults.set(preferences.weeklyTrendEnabled, forKey: weeklyTrendEnabledKey)
    }

    static func loadCampaignStats(
        for campaign: NotificationCampaign,
        from defaults: UserDefaults
    ) -> NotificationCampaignStats {
        let key = campaignStatsKey(for: campaign)
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationCampaignStats.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func saveCampaignStats(
        _ stats: NotificationCampaignStats,
        for campaign: NotificationCampaign,
        to defaults: UserDefaults
    ) {
        let key = campaignStatsKey(for: campaign)
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func loadCampaignContextStats(
        for campaign: NotificationCampaign,
        from defaults: UserDefaults
    ) -> [String: NotificationCampaignStats] {
        let key = campaignContextStatsKey(for: campaign)
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: NotificationCampaignStats].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func saveCampaignContextStats(
        _ stats: [String: NotificationCampaignStats],
        for campaign: NotificationCampaign,
        to defaults: UserDefaults
    ) {
        let key = campaignContextStatsKey(for: campaign)
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func loadTrackedDispatches(from defaults: UserDefaults) -> [TrackedDispatch] {
        guard let data = defaults.data(forKey: trackedDispatchesKey),
              let decoded = try? JSONDecoder().decode([TrackedDispatch].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveTrackedDispatches(
        _ dispatches: [TrackedDispatch],
        to defaults: UserDefaults
    ) {
        if let data = try? JSONEncoder().encode(dispatches) {
            defaults.set(data, forKey: trackedDispatchesKey)
        } else {
            defaults.removeObject(forKey: trackedDispatchesKey)
        }
    }

    static func loadReminderTimingStats(from defaults: UserDefaults) -> NotificationTimingStats {
        guard let data = defaults.data(forKey: seasonMilestoneReminderTimingStatsKey),
              let decoded = try? JSONDecoder().decode(NotificationTimingStats.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func saveReminderTimingStats(
        _ stats: NotificationTimingStats,
        to defaults: UserDefaults
    ) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: seasonMilestoneReminderTimingStatsKey)
        } else {
            defaults.removeObject(forKey: seasonMilestoneReminderTimingStatsKey)
        }
    }

    static func loadReminderTimingStatsByWeekday(
        from defaults: UserDefaults
    ) -> [String: NotificationTimingStats] {
        guard let data = defaults.data(forKey: seasonMilestoneReminderTimingStatsByWeekdayKey),
              let decoded = try? JSONDecoder().decode([String: NotificationTimingStats].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func saveReminderTimingStatsByWeekday(
        _ map: [String: NotificationTimingStats],
        to defaults: UserDefaults
    ) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: seasonMilestoneReminderTimingStatsByWeekdayKey)
        } else {
            defaults.removeObject(forKey: seasonMilestoneReminderTimingStatsByWeekdayKey)
        }
    }

    static func recommendedVariant(for stats: NotificationCampaignStats) -> NotificationVariant {
        let scoreA = stats.a.weightedScore
        let scoreB = stats.b.weightedScore
        if scoreA == scoreB {
            return stats.a.sent <= stats.b.sent ? .a : .b
        }
        return scoreA > scoreB ? .a : .b
    }

    static func recommendedTimingSlot(for stats: NotificationTimingStats) -> NotificationTimingSlot {
        let ranked = NotificationTimingSlot.allCases.sorted { lhs, rhs in
            let a = stats.stats(for: lhs)
            let b = stats.stats(for: rhs)
            if a.weightedScore != b.weightedScore {
                return a.weightedScore > b.weightedScore
            }
            return a.sent < b.sent
        }
        return ranked.first ?? .primeTime
    }

    private static func campaignStatsKey(for campaign: NotificationCampaign) -> String {
        switch campaign {
        case .seasonMilestoneReady:
            return seasonMilestoneReadyABStatsKey
        case .seasonMilestoneReminder:
            return seasonMilestoneReminderABStatsKey
        }
    }

    private static func campaignContextStatsKey(for campaign: NotificationCampaign) -> String {
        switch campaign {
        case .seasonMilestoneReady:
            return seasonMilestoneReadyABStatsByContextKey
        case .seasonMilestoneReminder:
            return seasonMilestoneReminderABStatsByContextKey
        }
    }
}
