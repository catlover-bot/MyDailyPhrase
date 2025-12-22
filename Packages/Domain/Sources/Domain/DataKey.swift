import Foundation

public enum DateKey {
    public static func todayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func dateByAddingDays(_ days: Int, from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}
