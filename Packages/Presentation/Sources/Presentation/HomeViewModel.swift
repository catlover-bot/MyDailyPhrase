import Foundation
import Domain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var promptText: String = ""
    @Published public var answerText: String = ""
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var isAnsweredToday: Bool = false

    // 保存結果を UI に見せる
    @Published public var saveMessage: String? = nil

    // 作品カード（ReflectionArtifact）
    @Published public private(set) var todayArtifact: ReflectionArtifact? = nil

    // 1年前の今日
    @Published public private(set) var oneYearAgoTitle: String = "1年前の今日"
    @Published public private(set) var oneYearAgoPrompt: String = ""
    @Published public private(set) var oneYearAgoAnswer: String = ""
    @Published public private(set) var hasOneYearAgo: Bool = false
    @Published public private(set) var oneYearAgoArtifact: ReflectionArtifact? = nil

    // ✅ チャレンジ受信
    @Published public private(set) var incomingChallenge: Entry? = nil
    // ✅ チャレンジ回答（編集用）
    @Published public var challengeAnswerText: String = ""

    private let getTodayEntry: GetTodayEntryUseCase
    private let saveTodayAnswer: SaveTodayAnswerUseCase
    private let computeStreak: ComputeStreakUseCase
    private let getEntryByOffset: GetEntryByOffsetUseCase
    private let getEntryByDateKey: GetEntryByDateKeyUseCase
    private let saveAnswerByDateKey: SaveAnswerByDateKeyUseCase

    // 作品化
    private let enrichEntry: EnrichEntryUseCase

    public init(
        getTodayEntry: GetTodayEntryUseCase,
        saveTodayAnswer: SaveTodayAnswerUseCase,
        computeStreak: ComputeStreakUseCase,
        getEntryByOffset: GetEntryByOffsetUseCase,
        enrichEntry: EnrichEntryUseCase,
        getEntryByDateKey: GetEntryByDateKeyUseCase,
        saveAnswerByDateKey: SaveAnswerByDateKeyUseCase
    ) {
        self.getTodayEntry = getTodayEntry
        self.saveTodayAnswer = saveTodayAnswer
        self.computeStreak = computeStreak
        self.getEntryByOffset = getEntryByOffset
        self.enrichEntry = enrichEntry
        self.getEntryByDateKey = getEntryByDateKey
        self.saveAnswerByDateKey = saveAnswerByDateKey
    }

    public func load() {
        let entry = getTodayEntry.execute()
        promptText = entry.prompt.text
        answerText = entry.answer ?? ""
        isAnsweredToday = (entry.answer?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        streak = computeStreak.execute()

        // 今日の作品カード
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        todayArtifact = trimmed.isEmpty ? nil : enrichEntry.execute(prompt: promptText, answer: trimmed)

        // 1年前の今日（-365日）
        if let old = getEntryByOffset.execute(days: -365),
           let ans = old.answer?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ans.isEmpty {
            hasOneYearAgo = true
            oneYearAgoPrompt = old.prompt.text
            oneYearAgoAnswer = ans
            oneYearAgoArtifact = enrichEntry.execute(prompt: oneYearAgoPrompt, answer: ans)
        } else {
            hasOneYearAgo = false
            oneYearAgoPrompt = ""
            oneYearAgoAnswer = ""
            oneYearAgoArtifact = nil
        }
    }

    public func submit() {
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveMessage = "回答が空です"
            return
        }

        saveTodayAnswer.execute(answer: trimmed)
        load()

        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
        saveMessage = "保存しました"
    }

    public func clearSaveMessage() { saveMessage = nil }

    // ✅ deep link 受信
    public func handleOpenURL(_ url: URL) {
        guard url.scheme == "mydailyphrase" else { return }
        guard url.host == "challenge" else { return }

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dateKey = comps.queryItems?.first(where: { $0.name == "dateKey" })?.value,
              dateKey.count == 8
        else { return }

        let e = getEntryByDateKey.execute(dateKey: dateKey)
        incomingChallenge = e
        // 既存回答があれば編集欄へ（別端末なら空のはず）
        challengeAnswerText = e.answer ?? ""
    }

    // ✅ チャレンジ回答を保存
    public func saveIncomingChallengeAnswer() {
        guard let dateKey = incomingChallenge?.dateKey else { return }

        let trimmed = challengeAnswerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveMessage = "回答が空です"
            return
        }

        saveAnswerByDateKey.execute(dateKey: dateKey, answer: trimmed)

        // 表示上も更新（再オープンせず反映させたい場合）
        if var e = incomingChallenge {
            e.answer = trimmed
            incomingChallenge = e
        }

        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
        saveMessage = "保存しました"
    }

    public func clearIncomingChallenge() {
        incomingChallenge = nil
        challengeAnswerText = ""
    }
}
