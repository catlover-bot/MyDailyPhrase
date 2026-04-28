import Foundation
@preconcurrency import Domain

public final class LocalPromptRepository: PromptRepository {

    private typealias PromptPool = (key: String, prompts: [String])

    private let promptPools: [PromptPool] = [
        (
            key: "self_reflection",
            prompts: [
                "今日の自分を一言で言うと？",
                "いまの自分に一番しっくりくる言葉は？",
                "今日の気分にタイトルを付けるなら？",
                "今の自分を色で表すと何色？その理由は？",
                "今日の自分に点数をつけるなら何点？",
                "朝の自分と夜の自分、何が変わった？",
                "今日の自分に足りなかったものは？",
                "今日の自分を褒めるならどこ？",
                "今週の自分らしさが出た瞬間は？",
                "最近の自分の口ぐせに気づいたことは？",
                "今日の自分を第三者として見るとどう見える？",
                "明日の自分に渡したい一言は？"
            ]
        ),
        (
            key: "gratitude",
            prompts: [
                "今日、感謝したいことは？",
                "当たり前だと思っていたけど実はありがたいことは？",
                "最近助けられた小さな出来事は？",
                "身近な人の行動で嬉しかったことは？",
                "今日の食事でありがたかったことは？",
                "今ある環境で恵まれていると感じる点は？",
                "今日の偶然に感謝できることは？",
                "最近の自分を支えてくれた存在は？",
                "過去の自分に感謝したい行動は？",
                "一年前の自分に伝えたい『ありがとう』は？",
                "感謝を伝えたいけど言えていない相手は？",
                "今日、感謝を行動で返すなら何をする？"
            ]
        ),
        (
            key: "mood",
            prompts: [
                "今の気分を天気にたとえると？",
                "今日いちばん強く残っている感情は？",
                "気持ちが軽くなった瞬間はいつ？",
                "少し引っかかっている気分の正体は何？",
                "今の自分に必要な言葉は？",
                "今日の心の波はどんな形だった？",
                "安心できた場面はあった？",
                "気分を切り替えるきっかけになったことは？",
                "今日の感情を色で表すなら何色？",
                "自分の気持ちに素直になれた瞬間は？",
                "いま抱えているモヤモヤを一言で言うと？",
                "今夜の自分を落ち着かせる一歩は？"
            ]
        ),
        (
            key: "growth",
            prompts: [
                "今日の学びは？",
                "今日の失敗から学べることは？",
                "最近できるようになったことは？",
                "繰り返しつまずく原因はどこにありそう？",
                "明日ひとつだけ改善するなら何？",
                "今日、勇気を出してやったことは？",
                "今週の伸びしろはどこだと思う？",
                "『次はこうする』を一つ決めるなら？",
                "今日の経験を誰かに教えるなら何を伝える？",
                "最近の成長を実感した瞬間は？",
                "今の習慣で将来効いてきそうなものは？",
                "自分の課題に名前をつけるなら？"
            ]
        ),
        (
            key: "relationships",
            prompts: [
                "今日いちばん心が動いた会話は？",
                "誰かの言葉で残っている一言は？",
                "今日、もっと丁寧に向き合えた相手は？",
                "最近距離が縮まった人とのきっかけは？",
                "人との関わりで反省したことは？",
                "今日、相手の立場で考えられた場面は？",
                "今の人間関係で大切にしたい価値観は？",
                "これから関係を深めたい相手は誰？",
                "最近の会話で救われた瞬間は？",
                "言えてよかった一言、言えなかった一言は？",
                "明日、誰にどんな声かけをしたい？",
                "今の自分が周りに与えている印象は？"
            ]
        ),
        (
            key: "challenge",
            prompts: [
                "今日いちばん挑戦したことは？",
                "先延ばししていたことを進めるなら何から？",
                "明日ひとつだけ良くできるなら何？",
                "今の自分が避けがちなことは何？",
                "今日の怖さを超えた一歩は？",
                "次の24時間でやる小さな挑戦は？",
                "『面倒』の先にある価値は何だった？",
                "今週中に終わらせたいことは？",
                "今日の集中を阻んだものは何？",
                "やらないと決めることで前進できることは？",
                "今日の判断で誇れる選択は？",
                "次に壁が来たらどう乗り越える？"
            ]
        ),
        (
            key: "small_wins",
            prompts: [
                "今日の小さな達成は？",
                "思ったよりちゃんとできたことは？",
                "今日の自分を一つ認めるなら？",
                "地味だけど前に進んだことは？",
                "先週より少し良くなったことは？",
                "今日は何を最後までやり切れた？",
                "自分のためにできた小さな行動は？",
                "今日の『よくやった』を一つ挙げるなら？",
                "誰にも気づかれなくても誇れることは？",
                "今日の積み上げを一言で残すなら？",
                "迷いながらでも進めたことは？",
                "明日の自信につながる小さな一歩は？"
            ]
        ),
        (
            key: "creativity",
            prompts: [
                "今日の出来事を一文で要約すると？",
                "今日を映画のタイトルにするなら？",
                "今日の気分を短い詩にすると？",
                "今日の一枚を言葉で描写すると？",
                "今日の自分をキャッチコピーにするなら？",
                "今の悩みを比喩で表すと何？",
                "今日のハイライトを3語で表すと？",
                "今日の音を一つ選ぶならどんな音？",
                "もし今日を漫画の1コマにするなら？",
                "いま頭の中にある景色はどんな風景？",
                "今日の気持ちを天気で表すと？",
                "自分だけの合言葉を作るなら？"
            ]
        ),
        (
            key: "wellbeing",
            prompts: [
                "今日、心が休まった瞬間は？",
                "いまの体調を一言で言うと？",
                "今日、無理をしたと感じる場面は？",
                "今日の睡眠・食事・運動で整えたい点は？",
                "呼吸が浅くなった瞬間はいつ？",
                "今日のストレス源と、その対処は？",
                "今夜の自分を労わる行動を一つ挙げるなら？",
                "最近の生活で減らしたい刺激は？",
                "今日いちばんリラックスできた時間は？",
                "明日の朝を楽にする準備は何ができる？",
                "いま心に余白を作るなら何をやめる？",
                "今日の自分に必要な優しさは？"
            ]
        ),
        (
            key: "future_design",
            prompts: [
                "1ヶ月後の自分に期待する変化は？",
                "今年中に形にしたいことは？",
                "最近の選択はどんな未来につながっている？",
                "理想の1日を3要素で書くなら？",
                "未来の自分が感謝する今日の行動は？",
                "次の週末をどう使うと満足度が高い？",
                "今の習慣を続けた先にある景色は？",
                "来月までに卒業したい思考パターンは？",
                "3年後の自分へ、今伝えるなら？",
                "今日の行動を将来の投資とみなすなら何？",
                "小さく始めるなら、まず何分使う？",
                "『そのうち』を今週に変えるなら何をする？"
            ]
        ),
        (
            key: "work_study",
            prompts: [
                "今日いちばん集中できた瞬間は？",
                "今日の仕事/学習で成果が出た工夫は？",
                "時間を使いすぎたことは何？",
                "優先順位の判断は適切だった？",
                "明日の最重要タスクは何？",
                "今日の会議/授業で得た気づきは？",
                "今の課題を分解すると最初の一歩は？",
                "今日の自分に足りなかった準備は？",
                "やる気が低いときに効く工夫は？",
                "今日のアウトプットを改善するならどこ？",
                "一番価値を生んだ30分は何をした？",
                "次に同じ作業をするときの時短アイデアは？"
            ]
        ),
        (
            key: "social_buzz",
            prompts: [
                "今週シェアしたくなる学びは何？",
                "友達に質問してみたいテーマは？",
                "今日の出来事で『共感されそう』なのはどこ？",
                "SNSに投稿するとしたら何を切り取る？",
                "誰かの背中を押せる一言を書くなら？",
                "コミュニティで話してみたいお題は？",
                "今週のマイベスト気づきは？",
                "最近の変化で人に話したいことは？",
                "自分と同じ悩みの人に伝えたいことは？",
                "今日の反省を前向きに共有するなら？",
                "明日の投稿ネタになる行動は何？",
                "今週のバズお題を作るならどんな質問にする？"
            ]
        )
    ]

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    public init() {}

    public var promptCount: Int {
        promptPools.reduce(into: 0) { count, pool in
            count += pool.prompts.count
        }
    }

    public func prompt(for dateKey: String) -> Prompt {
        guard !promptPools.isEmpty else {
            return Prompt(id: "fallback", text: "今日の気分を一言で表すと？")
        }

        let weekdayOffset = weekdayOffset(for: dateKey)
        let poolSeed = "\(dateKey)#pool#\(weekdayOffset)"
        let poolIndex = stableIndex(from: poolSeed, mod: promptPools.count)
        let pool = promptPools[(poolIndex + weekdayOffset) % promptPools.count]

        let promptSeed = "\(dateKey)#\(pool.key)"
        let promptIndex = stableIndex(from: promptSeed, mod: pool.prompts.count)
        let text = pool.prompts[promptIndex]
        let id = "\(pool.key)-\(String(format: "%03d", promptIndex + 1))"
        return Prompt(id: id, text: text)
    }

    // MARK: - Helpers

    private func stableIndex(from s: String, mod: Int) -> Int {
        guard mod > 0 else { return 0 }
        return Int(stableHash64(of: s) % UInt64(mod))
    }

    private func weekdayOffset(for dateKey: String) -> Int {
        guard let date = dateFormatter.date(from: dateKey) else { return 0 }
        return max(0, calendar.component(.weekday, from: date) - 1)
    }

    // FNV-1a 64-bit: 実行ごとに変わらない決定論ハッシュ
    private func stableHash64(of s: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
