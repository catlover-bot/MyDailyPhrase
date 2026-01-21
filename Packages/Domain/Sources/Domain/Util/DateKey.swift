import Foundation

public enum DateKey {

    // Core
    public static func key(of date: Date, calendar: Calendar = .current) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d%02d%02d", y, m, d)
    }

    public static func shiftedKey(base: Date = Date(),
                                  offsetDays: Int,
                                  calendar: Calendar = .current) -> String {
        let shifted = calendar.date(byAdding: .day, value: offsetDays, to: base) ?? base
        return key(of: shifted, calendar: calendar)
    }

    // ---- UseCase互換（timeZone版）ここから ----

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// UseCaseが呼んでいる: DateKey.key(for:timeZone:)
    public static func key(for date: Date, timeZone: TimeZone) -> String {
        key(of: date, calendar: calendar(for: timeZone))
    }

    /// UseCaseが呼んでいる: DateKey.todayKey(timeZone:)
    public static func todayKey(timeZone: TimeZone) -> String {
        key(for: Date(), timeZone: timeZone)
    }

    /// UseCaseが呼んでいる: DateKey.shiftedKey(from:days:timeZone:)
    public static func shiftedKey(from base: Date, days: Int, timeZone: TimeZone) -> String {
        let cal = calendar(for: timeZone)
        let shifted = cal.date(byAdding: .day, value: days, to: base) ?? base
        return key(of: shifted, calendar: cal)
    }

    // 任意：他が参照してもいいように残しておく
    public static var todayKey: String { key(of: Date()) }

    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        guard key.count == 8 else { return nil }
        let y = Int(key.prefix(4)) ?? 0
        let m = Int(key.dropFirst(4).prefix(2)) ?? 0
        let d = Int(key.dropFirst(6).prefix(2)) ?? 0
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return calendar.date(from: comps)
    }
}
