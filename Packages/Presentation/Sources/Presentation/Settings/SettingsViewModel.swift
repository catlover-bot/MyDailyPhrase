import Foundation
import Domain

public enum ReminderAuthorizationStatus: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    public var description: String {
        switch self {
        case .notDetermined:
            return "未許可"
        case .denied:
            return "システム設定で拒否"
        case .authorized:
            return "許可済み"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時許可"
        }
    }

    public var canSchedule: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        }
    }
}

public struct ReminderSettingsSnapshot: Equatable, Sendable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var authorizationStatus: ReminderAuthorizationStatus

    public init(
        isEnabled: Bool,
        hour: Int,
        minute: Int,
        authorizationStatus: ReminderAuthorizationStatus
    ) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.authorizationStatus = authorizationStatus
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var appVersionText: String
    @Published public private(set) var privacyPolicyURL: URL
    @Published public private(set) var supportURL: URL
    @Published public private(set) var localStorageStatement: String
    @Published public var reminderEnabled: Bool = false
    @Published public var reminderTime: Date = Date()
    @Published public private(set) var reminderAuthorizationText: String = ""
    @Published public private(set) var reminderAuthorizationStatus: ReminderAuthorizationStatus = .notDetermined
    @Published public private(set) var isUpdatingReminder: Bool = false
    @Published public private(set) var feedbackMessage: String? = nil

    private let deleteAllEntries: DeleteAllEntriesUseCase
    private let loadReminderSettings: () async -> ReminderSettingsSnapshot
    private let updateReminderSettings: (ReminderSettingsSnapshot) async -> ReminderSettingsSnapshot
    private let notificationCenter: NotificationCenter
    private let calendar: Calendar

    public init(
        appVersionText: String,
        privacyPolicyURL: URL,
        supportURL: URL,
        localStorageStatement: String = "回答はこのデバイス内に保存され、外部サーバーへ送信されません。",
        deleteAllEntries: DeleteAllEntriesUseCase,
        loadReminderSettings: @escaping () async -> ReminderSettingsSnapshot,
        updateReminderSettings: @escaping (ReminderSettingsSnapshot) async -> ReminderSettingsSnapshot,
        notificationCenter: NotificationCenter = .default,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.appVersionText = appVersionText
        self.privacyPolicyURL = privacyPolicyURL
        self.supportURL = supportURL
        self.localStorageStatement = localStorageStatement
        self.deleteAllEntries = deleteAllEntries
        self.loadReminderSettings = loadReminderSettings
        self.updateReminderSettings = updateReminderSettings
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    public func load() async {
        apply(await loadReminderSettings())
    }

    public func setReminderEnabled(_ isEnabled: Bool) async {
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }

        var snapshot = currentSnapshot()
        snapshot.isEnabled = isEnabled

        let updatedSnapshot = await updateReminderSettings(snapshot)
        apply(updatedSnapshot)

        if isEnabled {
            feedbackMessage = updatedSnapshot.isEnabled
                ? "毎日のリマインダーを設定しました"
                : "通知を有効にするにはシステム設定の許可が必要です"
        } else {
            feedbackMessage = "リマインダーをオフにしました"
        }
    }

    public func setReminderTime(_ date: Date) async {
        reminderTime = date
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }

        var snapshot = currentSnapshot()
        let components = calendar.dateComponents([.hour, .minute], from: date)
        snapshot.hour = components.hour ?? 20
        snapshot.minute = components.minute ?? 0

        let updatedSnapshot = await updateReminderSettings(snapshot)
        apply(updatedSnapshot)
        feedbackMessage = updatedSnapshot.isEnabled
            ? "リマインダー時刻を更新しました"
            : "次にリマインダーをオンにすると、この時刻が使われます"
    }

    public func deleteAllData() {
        deleteAllEntries.execute()
        feedbackMessage = "ローカルデータを削除しました"
        notificationCenter.post(name: .entryDidUpdate, object: nil)
    }

    public func clearFeedback() {
        feedbackMessage = nil
    }

    private func currentSnapshot() -> ReminderSettingsSnapshot {
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        return ReminderSettingsSnapshot(
            isEnabled: reminderEnabled,
            hour: components.hour ?? 20,
            minute: components.minute ?? 0,
            authorizationStatus: reminderAuthorizationStatus
        )
    }

    private func apply(_ snapshot: ReminderSettingsSnapshot) {
        reminderEnabled = snapshot.isEnabled
        reminderAuthorizationStatus = snapshot.authorizationStatus
        reminderAuthorizationText = snapshot.authorizationStatus.description
        reminderTime = Self.makeDisplayDate(hour: snapshot.hour, minute: snapshot.minute, calendar: calendar)
    }

    private static func makeDisplayDate(hour: Int, minute: Int, calendar: Calendar) -> Date {
        let safeHour = max(0, min(hour, 23))
        let safeMinute = max(0, min(minute, 59))
        let baseDate = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: safeHour, minute: safeMinute, second: 0, of: baseDate) ?? baseDate
    }
}
