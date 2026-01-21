import Foundation

public struct ImportChallengeToEntryUseCase: Sendable {
    private let entryRepo: EntryRepository

    public init(entryRepo: EntryRepository) {
        self.entryRepo = entryRepo
    }

    /// 既存の呼び出しスタイルに合わせる（CommunityViewModel 側が `importChallengeToEntry(challenge:)` でも動く）
    @discardableResult
    public func callAsFunction(challenge: ChallengeEvent) -> Entry {
        execute(challenge: challenge)
    }

    /// 受信 Challenge を「その日(dateKey)」の Entry に取り込む
    /// - 既存Entryがある場合: prompt を challenge の prompt に更新（answer / isFavorite は維持）
    /// - 無い場合: 新規 Entry を作って保存
    @discardableResult
    public func execute(challenge: ChallengeEvent) -> Entry {
        let dateKey = challenge.link.dateKey

        let prompt = Prompt(
            id: "challenge-\(dateKey)",
            text: challenge.link.prompt
        )

        if let existing = entryRepo.getEntry(dateKey: dateKey) {
            let updated = Entry(
                dateKey: existing.dateKey,
                prompt: prompt,
                answer: existing.answer,
                isFavorite: existing.isFavorite
            )
            entryRepo.upsertEntry(updated)
            return updated
        } else {
            let entry = Entry(
                dateKey: dateKey,
                prompt: prompt,
                answer: nil,
                isFavorite: false
            )
            entryRepo.upsertEntry(entry)
            return entry
        }
    }
}
