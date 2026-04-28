import Foundation
import UserNotifications
import Presentation

@MainActor
final class DailyReminderManager {
    private struct StoredReminderSettings: Codable {
        var isEnabled: Bool
        var hour: Int
        var minute: Int
    }

    private enum Constants {
        static let storageKey = "MyDailyPhrase.dailyReminder.v1"
        static let notificationIdentifier = "MyDailyPhrase.dailyReminder"
        static let defaultHour = 20
        static let defaultMinute = 0
    }

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter

    init(
        defaults: UserDefaults,
        center: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.center = center
    }

    func loadSnapshot() async -> ReminderSettingsSnapshot {
        var stored = loadStoredSettings()
        let status = await authorizationStatus()
        let effectiveEnabled = stored.isEnabled && status.canSchedule

        if stored.isEnabled != effectiveEnabled {
            stored.isEnabled = effectiveEnabled
            saveStoredSettings(stored)
            if !effectiveEnabled {
                center.removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])
            }
        }

        return ReminderSettingsSnapshot(
            isEnabled: effectiveEnabled,
            hour: stored.hour,
            minute: stored.minute,
            authorizationStatus: status
        )
    }

    func update(snapshot: ReminderSettingsSnapshot) async -> ReminderSettingsSnapshot {
        var stored = loadStoredSettings()
        stored.hour = max(0, min(snapshot.hour, 23))
        stored.minute = max(0, min(snapshot.minute, 59))

        if snapshot.isEnabled {
            let granted = await ensureAuthorization()
            stored.isEnabled = granted

            if granted {
                saveStoredSettings(stored)
                await scheduleDailyReminder(for: stored)
            } else {
                saveStoredSettings(stored)
                center.removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])
            }
        } else {
            stored.isEnabled = false
            saveStoredSettings(stored)
            center.removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])
        }

        let status = await authorizationStatus()
        let effectiveEnabled = stored.isEnabled && status.canSchedule

        if stored.isEnabled != effectiveEnabled {
            stored.isEnabled = effectiveEnabled
            saveStoredSettings(stored)
        }

        return ReminderSettingsSnapshot(
            isEnabled: effectiveEnabled,
            hour: stored.hour,
            minute: stored.minute,
            authorizationStatus: status
        )
    }

    private func loadStoredSettings() -> StoredReminderSettings {
        guard let data = defaults.data(forKey: Constants.storageKey) else {
            return StoredReminderSettings(
                isEnabled: false,
                hour: Constants.defaultHour,
                minute: Constants.defaultMinute
            )
        }

        do {
            return try JSONDecoder().decode(StoredReminderSettings.self, from: data)
        } catch {
            defaults.removeObject(forKey: Constants.storageKey)
            return StoredReminderSettings(
                isEnabled: false,
                hour: Constants.defaultHour,
                minute: Constants.defaultMinute
            )
        }
    }

    private func saveStoredSettings(_ settings: StoredReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Constants.storageKey)
    }

    private func ensureAuthorization() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await requestAuthorization()
        }
    }

    private func authorizationStatus() async -> ReminderAuthorizationStatus {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .denied
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func scheduleDailyReminder(for settings: StoredReminderSettings) async {
        center.removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "今日のひとことを残しましょう"
        content.body = "1分だけ、その日の気持ちや出来事を言葉にしてみませんか。"
        content.sound = .default

        var components = DateComponents()
        components.hour = settings.hour
        components.minute = settings.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }
}
