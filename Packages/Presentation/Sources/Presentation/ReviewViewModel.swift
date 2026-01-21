import Foundation
import Domain

// Presentation 側フォールバック（App から注入しない場合でも最低限動く）
private struct NullTextEnrichmentService: TextEnrichmentService {
    func enrich(prompt: String, answer: String, locale: Locale) -> ReflectionArtifact {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = a.isEmpty ? "未回答" : String(a.prefix(24)) + (a.count > 24 ? "…" : "")
        let summary = a.isEmpty ? "（まだ回答がありません）" : String(a.prefix(90)) + (a.count > 90 ? "…" : "")
        return ReflectionArtifact(title: title, summary: summary, keywords: [], moodTags: ["日常"])
    }
}

@MainActor
public final class ReviewViewModel: ObservableObject {

    public struct EntryWork: Identifiable, Equatable, Sendable {
        public let id: String
        public let dateKey: String
        public let promptText: String
        public let answerText: String
        public let artifact: ReflectionArtifact

        public init(dateKey: String, promptText: String, answerText: String, artifact: ReflectionArtifact) {
            self.id = dateKey
            self.dateKey = dateKey
            self.promptText = promptText
            self.answerText = answerText
            self.artifact = artifact
        }
    }

    public struct ReviewSummary: Equatable, Sendable, Codable {
        public let answeredCount: Int
        public let avgChars: Double?
        public let topWeekday: Int? // 1=日 ... 7=土

        public init(answeredCount: Int, avgChars: Double?, topWeekday: Int?) {
            self.answeredCount = answeredCount
            self.avgChars = avgChars
            self.topWeekday = topWeekday
        }

        public var avgCharsText: String {
            guard let a = avgChars else { return "—" }
            return "\(Int(a.rounded()))"
        }

        public var topWeekdayText: String {
            guard let w = topWeekday else { return "—" }
            let jp = ["日", "月", "火", "水", "木", "金", "土"]
            return (1...7).contains(w) ? jp[w - 1] : "—"
        }
    }

    private let listEntries: ListEntriesUseCase
    private let enrichEntry: EnrichEntryUseCase
    private let timeZone: TimeZone

    @Published public private(set) var randomWork: EntryWork?
    @Published public private(set) var oneYearAgoWork: EntryWork?
    @Published public private(set) var oneWeekAgoWork: EntryWork?
    @Published public private(set) var oneMonthAgoWork: EntryWork?

    @Published public private(set) var weekSummary: ReviewSummary?
    @Published public private(set) var monthSummary: ReviewSummary?
    @Published public private(set) var weekSummaryTitle: String = "直近7日"
    @Published public private(set) var monthSummaryTitle: String = "直近30日"

    private var allEntries: [Entry] = []
    private var byDateKey: [String: Entry] = [:]
    private var datedEntries: [(entry: Entry, date: Date)] = []

    // ✅ AppContainer が呼ぶ initializer（enrichEntry を受け取る）
    public init(
        listEntries: ListEntriesUseCase,
        enrichEntry: EnrichEntryUseCase,
        timeZone: TimeZone = .current
    ) {
        self.listEntries = listEntries
        self.enrichEntry = enrichEntry
        self.timeZone = timeZone
    }

    // ✅ 互換用（enrichEntry を渡さない呼び出しを壊さない）
    public convenience init(
        listEntries: ListEntriesUseCase,
        timeZone: TimeZone = .current
    ) {
        let fallback = EnrichEntryUseCase(service: NullTextEnrichmentService(), locale: .current)
        self.init(listEntries: listEntries, enrichEntry: fallback, timeZone: timeZone)
    }

    public func load() {
        allEntries = listEntries.execute()
        byDateKey = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.dateKey, $0) })

        datedEntries = allEntries.compactMap { e in
            guard let d = Self.date(from: e.dateKey, timeZone: timeZone) else { return nil }
            return (e, d)
        }

        shuffle()
        computeOneYearAgo()
        computeOffsetCards()
        computeSummaries()
    }

    public func shuffle() {
        guard let e = allEntries.randomElement() else {
            randomWork = nil
            return
        }
        randomWork = makeWork(from: e)
    }

    public var shareText: String {
        let w = randomWork ?? oneYearAgoWork ?? oneWeekAgoWork ?? oneMonthAgoWork
        guard let work = w else { return "【MyDailyPhrase】まだ記録がありません" }

        let tags = work.artifact.moodTags.isEmpty ? "" : " / " + work.artifact.moodTags.joined(separator: "・")
        return """
        【MyDailyPhrase】\(work.artifact.title)\(tags)
        日付: \(formatDateKey(work.dateKey))
        お題: \(work.promptText)
        要約: \(work.artifact.summary)
        回答: \(work.answerText.isEmpty ? "（未回答）" : work.answerText)
        """
    }

    private func makeWork(from entry: Entry) -> EntryWork {
        let p = entry.prompt.text
        let a = (entry.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artifact = enrichEntry.execute(prompt: p, answer: a)
        return EntryWork(dateKey: entry.dateKey, promptText: p, answerText: a, artifact: artifact)
    }

    private func computeOneYearAgo() {
        let todayKey = Self.todayDateKey(timeZone: timeZone)
        guard let today = Self.date(from: todayKey, timeZone: timeZone) else {
            oneYearAgoWork = nil
            return
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        guard let oneYearAgo = cal.date(byAdding: .year, value: -1, to: today) else {
            oneYearAgoWork = nil
            return
        }

        let key = Self.dateKey(from: oneYearAgo, timeZone: timeZone)
        oneYearAgoWork = byDateKey[key].map { makeWork(from: $0) }
    }

    private func computeOffsetCards() {
        let todayKey = Self.todayDateKey(timeZone: timeZone)
        guard let today = Self.date(from: todayKey, timeZone: timeZone) else {
            oneWeekAgoWork = nil
            oneMonthAgoWork = nil
            return
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        if let d = cal.date(byAdding: .day, value: -7, to: today) {
            let key = Self.dateKey(from: d, timeZone: timeZone)
            oneWeekAgoWork = byDateKey[key].map { makeWork(from: $0) }
        } else {
            oneWeekAgoWork = nil
        }

        if let d = cal.date(byAdding: .month, value: -1, to: today) {
            let key = Self.dateKey(from: d, timeZone: timeZone)
            oneMonthAgoWork = byDateKey[key].map { makeWork(from: $0) }
        } else {
            oneMonthAgoWork = nil
        }
    }

    private func computeSummaries() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let endExclusive = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now

        let weekStart = cal.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        weekSummary = computeSummary(start: weekStart, endExclusive: endExclusive, calendar: cal)
        weekSummaryTitle = "直近7日（\(formatMonthDay(weekStart))〜\(formatMonthDay(todayStart))）"

        let monthStart = cal.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        monthSummary = computeSummary(start: monthStart, endExclusive: endExclusive, calendar: cal)
        monthSummaryTitle = "直近30日（\(formatMonthDay(monthStart))〜\(formatMonthDay(todayStart))）"
    }

    private func computeSummary(start: Date, endExclusive: Date, calendar: Calendar) -> ReviewSummary {
        let inRange = datedEntries.filter { (_, d) in d >= start && d < endExclusive }

        let answered = inRange.compactMap { (e, d) -> (Int, Int)? in
            let a = (e.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !a.isEmpty else { return nil }
            return (a.count, calendar.component(.weekday, from: d))
        }

        let answeredCount = answered.count
        guard answeredCount > 0 else { return ReviewSummary(answeredCount: 0, avgChars: nil, topWeekday: nil) }

        let totalChars = answered.reduce(0) { $0 + $1.0 }
        let avg = Double(totalChars) / Double(answeredCount)

        var counts: [Int: Int] = [:]
        answered.forEach { counts[$0.1, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key

        return ReviewSummary(answeredCount: answeredCount, avgChars: avg, topWeekday: top)
    }

    private func formatDateKey(_ key: String) -> String {
        guard key.count == 8 else { return key }
        let y = key.prefix(4)
        let m = key.dropFirst(4).prefix(2)
        let d = key.suffix(2)
        return "\(y)-\(m)-\(d)"
    }

    private func formatMonthDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = timeZone
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }

    private static func todayDateKey(timeZone: TimeZone) -> String {
        dateKey(from: Date(), timeZone: timeZone)
    }

    private static func dateKey(from date: Date, timeZone: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = timeZone
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: date)
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
