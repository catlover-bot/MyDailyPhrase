import Foundation
@preconcurrency import Domain


public final class LocalPromptRepository: PromptRepository {

    private let prompts: [Prompt] = [
        Prompt(id: "p001", text: "今日いちばん良かったことは？"),
        Prompt(id: "p002", text: "今日の自分を一言で言うと？"),
        Prompt(id: "p003", text: "今日、感謝したいことは？"),
        Prompt(id: "p004", text: "明日ひとつだけ良くできるなら何？"),
        Prompt(id: "p005", text: "今日の学びは？"),
        Prompt(id: "p006", text: "今日の自分を褒める点は？"),
        Prompt(id: "p007", text: "今日いちばん集中できた瞬間は？"),
        Prompt(id: "p008", text: "今日いちばん心が動いた出来事は？"),
        Prompt(id: "p009", text: "今日の出来事を一文で要約すると？"),
        Prompt(id: "p010", text: "最近の自分に足りないと思うものは？")
    ]

    public init() {}

    /// Domain のプロトコルに合わせる（あなたの Domain は dateKey が String になっている想定）
    public func prompt(for dateKey: String) -> Prompt {
        let idx = stableIndex(from: dateKey, mod: prompts.count)
        return prompts[idx]
    }

    // MARK: - Helpers

    /// dateKey の文字列から、毎回同じ index を安定生成する（簡易ハッシュ）
    private func stableIndex(from s: String, mod: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(s)
        let value = hasher.finalize()
        // finalize は負にもなるので正規化
        let normalized = value == Int.min ? 0 : abs(value)
        return normalized % max(mod, 1)
    }
}
