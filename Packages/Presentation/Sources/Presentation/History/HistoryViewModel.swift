import Foundation
import Domain

@MainActor
public final class HistoryViewModel: ObservableObject {
    private let listEntries: ListEntriesUseCase
    private let toggleFavorite: ToggleFavoriteUseCase
    private let timeZone: TimeZone

    @Published public private(set) var entries: [Entry] = []

    @Published public var query: String = "" { didSet { apply() } }
    @Published public var onlyUnanswered: Bool = false { didSet { apply() } }
    @Published public var onlyFavorites: Bool = false { didSet { apply() } }
    @Published public var period: HistoryPeriod = .all { didSet { apply() } }

    private var allEntries: [Entry] = []

    public init(
        listEntries: ListEntriesUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        timeZone: TimeZone = .current
    ) {
        self.listEntries = listEntries
        self.toggleFavorite = toggleFavorite
        self.timeZone = timeZone
    }

    public func load() {
        let items = listEntries.execute()
        self.allEntries = items
        apply()
    }

    public func resetFilters() {
        query = ""
        onlyUnanswered = false
        onlyFavorites = false
        period = .all
        apply()
    }

    public func toggleFavorite(dateKey: String) {
        toggleFavorite.execute(dateKey: dateKey)
        // 反映を確実にする（小規模なので reload でOK）
        load()
        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
    }

    private func apply() {
        var xs = allEntries

        // 期間
        xs = xs.filter { period.contains(dateKey: $0.dateKey, timeZone: timeZone) }

        // ★だけ
        if onlyFavorites {
            xs = xs.filter { $0.isFavorite }
        }

        // 未回答だけ
        if onlyUnanswered {
            xs = xs.filter {
                let a = ($0.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return a.isEmpty
            }
        }

        // 検索
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            xs = xs.filter { e in
                let prompt = e.prompt.text.lowercased()
                let ans = (e.answer ?? "").lowercased()
                return prompt.contains(q) || ans.contains(q)
            }
        }

        // ★優先 → 新しい順
        xs.sort {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.dateKey > $1.dateKey
        }

        self.entries = xs
    }
}

public enum HistoryPeriod: String, CaseIterable, Identifiable {
    case all
    case thisMonth
    case lastMonth
    case thisYear

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "全期間"
        case .thisMonth: return "今月"
        case .lastMonth: return "先月"
        case .thisYear: return "今年"
        }
    }

    fileprivate func contains(dateKey: String, timeZone: TimeZone) -> Bool {
        guard let d = Self.date(from: dateKey, timeZone: timeZone) else { return true }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = Date()

        switch self {
        case .all:
            return true

        case .thisYear:
            let y1 = cal.component(.year, from: d)
            let y2 = cal.component(.year, from: now)
            return y1 == y2

        case .thisMonth:
            let a = cal.dateComponents([.year, .month], from: d)
            let b = cal.dateComponents([.year, .month], from: now)
            return a.year == b.year && a.month == b.month

        case .lastMonth:
            guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return false }
            let a = cal.dateComponents([.year, .month], from: d)
            let b = cal.dateComponents([.year, .month], from: lastMonth)
            return a.year == b.year && a.month == b.month
        }
    }

    private static func date(from dateKey: String, timeZone: TimeZone) -> Date? {
        guard dateKey.count == 8 else { return nil }
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = timeZone
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd"
        return fmt.date(from: dateKey)
    }
}
