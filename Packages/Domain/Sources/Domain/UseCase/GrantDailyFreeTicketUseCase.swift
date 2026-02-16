import Foundation

public struct GrantDailyFreeTicketUseCase: Sendable {
    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase
    private let timeZone: TimeZone
    private let dailyBonusTickets: @Sendable () -> Int

    public init(
        get: GetMyProfileUseCase,
        update: UpdateMyProfileUseCase,
        timeZone: TimeZone = .current,
        dailyBonusTickets: @escaping @Sendable () -> Int = { 0 }
    ) {
        self.get = get
        self.update = update
        self.timeZone = timeZone
        self.dailyBonusTickets = dailyBonusTickets
    }

    /// 付与したら true、付与済みなら false
    @discardableResult
    public func callAsFunction() -> Bool {
        grantedTicketCountIfNeeded() > 0
    }

    /// 付与した券数を返す（付与済みなら0）
    public func grantedTicketCountIfNeeded() -> Int {
        let today = ymdString(Date(), timeZone: timeZone)
        let p = get()

        if p.lastFreeTicketDateKey == today {
            return 0
        }

        let bonus = max(0, dailyBonusTickets())
        let ticketCount = 1 + bonus
        _ = update(
            gachaTickets: p.gachaTickets + ticketCount,
            lastFreeTicketDateKey: today
        )
        return ticketCount
    }

    private func ymdString(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
