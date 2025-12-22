import Foundation
import Domain

public struct LocalPromptRepository: PromptRepository, Sendable {
    private let prompts: [Prompt]

    public init() {
        self.prompts = [
            Prompt(id: 0, text: "今日いちばん良かったことは？"),
            Prompt(id: 1, text: "最近ハマっていることは？"),
            Prompt(id: 2, text: "今の気分を一言で言うと？"),
            Prompt(id: 3, text: "明日の自分にひとこと。"),
            Prompt(id: 4, text: "最近の“学び”を一言で。")
        ]
    }

    public func prompt(for date: Date) -> Prompt {
        let key = DateKey.todayKey(date)
        let h = abs(key.hashValue)
        return prompts[h % prompts.count]
    }
}
