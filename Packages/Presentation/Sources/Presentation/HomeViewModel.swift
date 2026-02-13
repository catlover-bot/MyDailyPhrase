import Foundation
import Domain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var promptText: String = ""
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

    // ✅ NEW: 選択中の装飾ID（ShareCardに渡す）
    @Published public private(set) var selectedDecorationId: String = "classic"

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

    public init(
        getTodayEntry: GetTodayEntryUseCase,
        saveTodayAnswer: SaveTodayAnswerUseCase,
        computeStreak: ComputeStreakUseCase,
        getEntryByOffset: GetEntryByOffsetUseCase,
        enrichEntry: EnrichEntryUseCase,
        getEntryByDateKey: GetEntryByDateKeyUseCase,
        saveAnswerByDateKey: SaveAnswerByDateKeyUseCase,
        getMyProfile: GetMyProfileUseCase,
        updateMyProfile: UpdateMyProfileUseCase
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
    }

    public func load() {
        let entry = getTodayEntry.execute()
        promptText = entry.prompt.text
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

        _ = updateMyProfile(
            gachaTickets: p.gachaTickets + 1,
            lastFreeTicketDateKey: todayKey
        )
    }

    public func clearSaveMessage() { saveMessage = nil }

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
}
