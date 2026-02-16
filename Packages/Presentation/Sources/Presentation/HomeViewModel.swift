import Foundation
import Domain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var promptText: String = ""
    @Published public private(set) var promptBoosters: [String] = []
    @Published public var answerText: String = ""
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var isAnsweredToday: Bool = false

    @Published public var saveMessage: String? = nil
    @Published public private(set) var todayArtifact: ReflectionArtifact? = nil

    @Published public private(set) var oneYearAgoTitle: String = "1年前の今日"
    @Published public private(set) var oneYearAgoPrompt: String = ""
    @Published public private(set) var oneYearAgoAnswer: String = ""
    @Published public private(set) var hasOneYearAgo: Bool = false
    @Published public private(set) var oneYearAgoArtifact: ReflectionArtifact? = nil

    @Published public private(set) var incomingChallenge: Entry? = nil
    @Published public var challengeAnswerText: String = ""
    @Published public private(set) var todayDateKey: String = ""

    // ✅ NEW: 選択中の装飾ID（ShareCardに渡す）
    @Published public private(set) var selectedDecorationId: String = "classic"
    @Published public private(set) var gachaTickets: Int = 0
    @Published public private(set) var shareMissionDailyCount: Int = 0
    @Published public private(set) var shareMissionLifetimeCount: Int = 0
    @Published public private(set) var shareMissionClaimedToday: Bool = false
    @Published public private(set) var shareMissionStreakDays: Int = 0
    @Published public private(set) var shareMissionBestStreakDays: Int = 0

    private let getTodayEntry: GetTodayEntryUseCase
    private let saveTodayAnswer: SaveTodayAnswerUseCase
    private let computeStreak: ComputeStreakUseCase
    private let getEntryByOffset: GetEntryByOffsetUseCase
    private let getEntryByDateKey: GetEntryByDateKeyUseCase
    private let saveAnswerByDateKey: SaveAnswerByDateKeyUseCase

    private let enrichEntry: EnrichEntryUseCase

    // ✅ NEW: プロフィール（装飾/無料券付与用）
    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
    private let makeChallengeShareURL: (String, String) -> URL?
    private let dailyFreeTicketBonusProvider: @Sendable () -> Int
    private let shareDefaults: UserDefaults
    private let shareMissionTimeZone: TimeZone

    private let shareMissionDateKeyStoreKey = "MyDailyPhrase.shareMission.dateKey.v1"
    private let shareMissionDailyCountStoreKey = "MyDailyPhrase.shareMission.dailyCount.v1"
    private let shareMissionLifetimeCountStoreKey = "MyDailyPhrase.shareMission.lifetimeCount.v1"
    private let shareMissionClaimedStoreKey = "MyDailyPhrase.shareMission.claimedToday.v1"
    private let shareMissionStreakDaysStoreKey = "MyDailyPhrase.shareMission.streakDays.v1"
    private let shareMissionBestStreakStoreKey = "MyDailyPhrase.shareMission.bestStreakDays.v1"
    private let shareMissionLastShareDateKeyStoreKey = "MyDailyPhrase.shareMission.lastShareDateKey.v1"

    public let shareMissionDailyTarget: Int = 3
    public let shareMissionRewardTickets: Int = 2
    public let shareMissionStreakBonusEveryDays: Int = 7
    public let shareMissionStreakRewardTickets: Int = 5
    private let promptBoosterTemplates: [String] = [
        "その出来事で一番強かった感情は？",
        "その感情が生まれた背景は？",
        "5分だけ時間が戻るなら何を変える？",
        "次に同じ状況が来たらどうする？",
        "他人視点だとこの出来事はどう見える？",
        "今日の行動で誇れる小さな一歩は？",
        "今日の反省を1行の行動にすると？",
        "明日の自分を助ける準備を一つ書くなら？",
        "今の悩みを分解すると最小単位は？",
        "この経験から得た教訓を短く言うと？",
        "今日の出来事を象徴するキーワードは？",
        "いま最も優先すべきことは何？",
        "今の自分に必要な休息は何？",
        "今日の会話で印象に残った一言は？",
        "感謝を伝えるなら誰に何を言う？",
        "今日の失敗を価値に変えるなら？",
        "この出来事を1週間後にどう捉えていたい？",
        "1年後の自分なら何と助言する？",
        "行動のハードルを10分版にすると何をする？",
        "今日の自分に100点中何点をつける？",
        "いま一番手放したい思い込みは？",
        "今日の自分らしさが出た瞬間は？",
        "次の一歩を邪魔しているものは？",
        "今日を一言で締めるなら？"
    ]

    public init(
        getTodayEntry: GetTodayEntryUseCase,
        saveTodayAnswer: SaveTodayAnswerUseCase,
        computeStreak: ComputeStreakUseCase,
        getEntryByOffset: GetEntryByOffsetUseCase,
        enrichEntry: EnrichEntryUseCase,
        getEntryByDateKey: GetEntryByDateKeyUseCase,
        saveAnswerByDateKey: SaveAnswerByDateKeyUseCase,
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase,
        dailyFreeTicketBonusProvider: @escaping @Sendable () -> Int = { 0 },
        shareDefaults: UserDefaults = .standard,
        shareMissionTimeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current,
        makeChallengeShareURL: @escaping (String, String) -> URL? = { dateKey, _ in
            URL(string: "mydailyphrase://challenge?dateKey=\(dateKey)")
        }
    ) {
        self.getTodayEntry = getTodayEntry
        self.saveTodayAnswer = saveTodayAnswer
        self.computeStreak = computeStreak
        self.getEntryByOffset = getEntryByOffset
        self.enrichEntry = enrichEntry
        self.getEntryByDateKey = getEntryByDateKey
        self.saveAnswerByDateKey = saveAnswerByDateKey
        self.getMyProfile = getMyProfile
        self.updateMyProfile = updateMyProfile
        self.dailyFreeTicketBonusProvider = dailyFreeTicketBonusProvider
        self.shareDefaults = shareDefaults
        self.shareMissionTimeZone = shareMissionTimeZone
        self.makeChallengeShareURL = makeChallengeShareURL
    }

    public var canClaimShareMissionReward: Bool {
        shareMissionDailyCount >= shareMissionDailyTarget && !shareMissionClaimedToday
    }

    public var shareMissionRemainingCount: Int {
        max(0, shareMissionDailyTarget - shareMissionDailyCount)
    }

    public var shareMissionDaysUntilStreakBonus: Int {
        let step = max(1, shareMissionStreakBonusEveryDays)
        let remainder = shareMissionStreakDays % step
        return remainder == 0 ? step : (step - remainder)
    }

    public func load() {
        let entry = getTodayEntry.execute()
        todayDateKey = entry.dateKey
        promptText = entry.prompt.text
        promptBoosters = buildPromptBoosters(dateKey: entry.dateKey, prompt: entry.prompt.text)
        answerText = entry.answer ?? ""
        isAnsweredToday = (entry.answer?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        streak = computeStreak.execute()

        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        todayArtifact = trimmed.isEmpty ? nil : enrichEntry.execute(prompt: promptText, answer: trimmed)

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

        // ✅ 選択装飾を反映
        let p = getMyProfile()
        selectedDecorationId = p.selectedDecorationId
        gachaTickets = p.gachaTickets
        refreshShareMissionState()
    }

    public func submit() {
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveMessage = "回答が空です"
            return
        }

        saveTodayAnswer.execute(answer: trimmed)

        // ✅ 1日1回：回答保存時に無料ガチャ券+1（付与済みならスキップ）
        grantDailyGachaTicketIfNeeded()

        load()
        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
        saveMessage = "保存しました"
    }

    private func grantDailyGachaTicketIfNeeded() {
        let tz = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let todayKey = DateKey.todayKey(timeZone: tz)

        let p = getMyProfile()
        if p.lastFreeTicketDateKey == todayKey { return }

        let bonus = max(0, dailyFreeTicketBonusProvider())
        let ticketCount = 1 + bonus

        _ = updateMyProfile(
            gachaTickets: p.gachaTickets + ticketCount,
            lastFreeTicketDateKey: todayKey
        )
    }

    public func clearSaveMessage() { saveMessage = nil }

    public func buildChallengeShareURLForCurrentPrompt() -> URL? {
        let dateKey = todayDateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dateKey.isEmpty else { return nil }
        guard !prompt.isEmpty else { return URL(string: "mydailyphrase://challenge?dateKey=\(dateKey)") }
        return makeChallengeShareURL(dateKey, prompt) ?? URL(string: "mydailyphrase://challenge?dateKey=\(dateKey)")
    }

    public func registerShareAction() {
        normalizeShareMissionDateIfNeeded()
        let isFirstShareToday = shareMissionDailyCount == 0

        shareMissionDailyCount += 1
        shareMissionLifetimeCount += 1
        let streakBonusMessage = isFirstShareToday ? advanceShareStreakForToday() : nil
        persistShareMissionState()

        if let streakBonusMessage {
            saveMessage = streakBonusMessage
        } else if canClaimShareMissionReward {
            saveMessage = "シェアミッション達成。報酬を受け取れます（チケット+\(shareMissionRewardTickets)）"
        } else if shareMissionDailyCount == 1 {
            saveMessage = "シェアを記録しました。あと\(shareMissionRemainingCount)回で報酬です"
        }
        NotificationCenter.default.post(name: .shareMissionDidUpdate, object: nil)
    }

    public func claimShareMissionReward() {
        guard canClaimShareMissionReward else { return }

        let profile = updateMyProfile(
            addGachaTickets: shareMissionRewardTickets
        )
        gachaTickets = profile.gachaTickets
        shareMissionClaimedToday = true
        persistShareMissionState()
        saveMessage = "シェア報酬を受け取りました（チケット+\(shareMissionRewardTickets)）"
        NotificationCenter.default.post(name: .shareMissionDidUpdate, object: nil)
    }

    public func handleOpenURL(_ url: URL) {
        guard url.scheme == "mydailyphrase" else { return }
        guard url.host == "challenge" else { return }

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dateKey = comps.queryItems?.first(where: { $0.name == "dateKey" })?.value,
              dateKey.count == 8
        else { return }

        let e = getEntryByDateKey.execute(dateKey: dateKey)
        incomingChallenge = e
        challengeAnswerText = e.answer ?? ""
    }

    public func saveIncomingChallengeAnswer() {
        guard let dateKey = incomingChallenge?.dateKey else { return }

        let trimmed = challengeAnswerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveMessage = "回答が空です"
            return
        }

        saveAnswerByDateKey.execute(dateKey: dateKey, answer: trimmed)

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

    public func applyPromptBooster(_ booster: String) {
        let trimmed = booster.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let line = "・\(trimmed)"
        let normalizedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedAnswer.isEmpty {
            answerText = "\(line)\n"
        } else if !answerText.contains(line) {
            answerText += answerText.hasSuffix("\n") ? "\(line)\n" : "\n\(line)\n"
        }
        saveMessage = "深掘りお題を回答欄に追加しました"
    }

    private func refreshShareMissionState() {
        normalizeShareMissionDateIfNeeded()
        shareMissionDailyCount = max(0, shareDefaults.integer(forKey: shareMissionDailyCountStoreKey))
        shareMissionLifetimeCount = max(0, shareDefaults.integer(forKey: shareMissionLifetimeCountStoreKey))
        shareMissionClaimedToday = shareDefaults.bool(forKey: shareMissionClaimedStoreKey)
        shareMissionStreakDays = max(0, shareDefaults.integer(forKey: shareMissionStreakDaysStoreKey))
        shareMissionBestStreakDays = max(0, shareDefaults.integer(forKey: shareMissionBestStreakStoreKey))
    }

    private func normalizeShareMissionDateIfNeeded() {
        let todayKey = DateKey.todayKey(timeZone: shareMissionTimeZone)
        let storedDateKey = shareDefaults.string(forKey: shareMissionDateKeyStoreKey)
        guard storedDateKey != todayKey else { return }

        shareDefaults.set(todayKey, forKey: shareMissionDateKeyStoreKey)
        shareDefaults.set(0, forKey: shareMissionDailyCountStoreKey)
        shareDefaults.set(false, forKey: shareMissionClaimedStoreKey)
        shareMissionDailyCount = 0
        shareMissionClaimedToday = false
    }

    private func persistShareMissionState() {
        shareDefaults.set(shareMissionDailyCount, forKey: shareMissionDailyCountStoreKey)
        shareDefaults.set(shareMissionLifetimeCount, forKey: shareMissionLifetimeCountStoreKey)
        shareDefaults.set(shareMissionClaimedToday, forKey: shareMissionClaimedStoreKey)
        shareDefaults.set(shareMissionStreakDays, forKey: shareMissionStreakDaysStoreKey)
        shareDefaults.set(shareMissionBestStreakDays, forKey: shareMissionBestStreakStoreKey)
    }

    private func advanceShareStreakForToday() -> String? {
        let todayKey = DateKey.todayKey(timeZone: shareMissionTimeZone)
        let lastShareDateKey = shareDefaults.string(forKey: shareMissionLastShareDateKeyStoreKey)

        if let lastShareDateKey, isConsecutiveDay(from: lastShareDateKey, to: todayKey) {
            shareMissionStreakDays += 1
        } else {
            shareMissionStreakDays = 1
        }

        shareMissionBestStreakDays = max(shareMissionBestStreakDays, shareMissionStreakDays)
        shareDefaults.set(todayKey, forKey: shareMissionLastShareDateKeyStoreKey)

        let step = max(1, shareMissionStreakBonusEveryDays)
        guard shareMissionStreakDays >= step, shareMissionStreakDays % step == 0 else {
            return nil
        }

        let profile = updateMyProfile(addGachaTickets: shareMissionStreakRewardTickets)
        gachaTickets = profile.gachaTickets
        return "連続シェア\(shareMissionStreakDays)日達成。ボーナスチケット+\(shareMissionStreakRewardTickets)"
    }

    private func isConsecutiveDay(from previousKey: String, to currentKey: String) -> Bool {
        guard previousKey.count == 8, currentKey.count == 8 else { return false }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = shareMissionTimeZone

        guard let previousDate = DateKey.date(from: previousKey, calendar: cal),
              let nextDate = cal.date(byAdding: .day, value: 1, to: previousDate) else {
            return false
        }
        let nextKey = DateKey.key(for: nextDate, timeZone: shareMissionTimeZone)
        return nextKey == currentKey
    }

    private func buildPromptBoosters(dateKey: String, prompt: String) -> [String] {
        guard !promptBoosterTemplates.isEmpty else { return [] }
        var results: [String] = []
        var seen: Set<Int> = []
        let seed = "\(dateKey)|\(prompt)"
        var offset = 0

        while results.count < 3 && seen.count < promptBoosterTemplates.count {
            let idx = stableIndex(from: "\(seed)#\(offset)", mod: promptBoosterTemplates.count)
            offset += 1
            guard seen.insert(idx).inserted else { continue }
            results.append(promptBoosterTemplates[idx])
        }
        return results
    }

    private func stableIndex(from raw: String, mod: Int) -> Int {
        guard mod > 0 else { return 0 }
        return Int(stableHash64(raw) % UInt64(mod))
    }

    private func stableHash64(_ raw: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
