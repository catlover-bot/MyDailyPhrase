import Foundation

public struct GrantDailyFreeTicketUseCase: Sendable {
    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase
    private let timeZone: TimeZone

    public init(
        get: GetMyProfileUseCase,
        update: UpdateMyProfileUseCase,
        timeZone: TimeZone = .current
    ) {
        self.get = get
        self.update = update
        self.timeZone = timeZone
    }

    /// 付与したら true、付与済みなら false
    @discardableResult
    public func callAsFunction() -> Bool {
        let today = ymdString(Date(), timeZone: timeZone)
        let p = get()

        if p.lastFreeTicketDateKey == today {
            return false
        }

        _ = update(
            gachaTickets: p.gachaTickets + 1,
            lastFreeTicketDateKey: today
        )
        return true
    }

    private func ymdString(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
