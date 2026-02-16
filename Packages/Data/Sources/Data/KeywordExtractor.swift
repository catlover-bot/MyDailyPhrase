import Foundation
import NaturalLanguage

enum KeywordExtractor {
    /// prompt / answer から “それっぽい日本語キーワード” を抽出する。
    /// - 方針:
    ///   - NLTokenizer(.word) で分かち書き
    ///   - NLTagger(.nameTypeOrLexicalClass) で固有表現/名詞を重み付け
    ///   - “純ひらがな” を強く抑制（ノイズ源）
    ///   - 日付/URL/数字を排除
    ///   - 隣接トークンを軽く結合して複合語を作る
    static func extract(prompt: String, answer: String, max: Int = 6, locale: Locale = .current) -> [String] {
        let p = normalizeText(prompt)
        let a = normalizeText(answer)

        let text = "\(p)\n\(a)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // 回答に含まれる語を優先し、問いの汎用語を抑制する。
        let promptTokens = Set(tokenizeWords(p).map(normalizeToken).filter { !$0.isEmpty })
        let answerTokens = Set(tokenizeWords(a).map(normalizeToken).filter { !$0.isEmpty })

        // 1) トークン化（単語列）
        let words = tokenizeWords(text).map(normalizeToken).filter { !$0.isEmpty }
        if words.isEmpty { return fallback(answer: a, prompt: p, max: max) }

        // 2) タグ付け（固有表現/名詞ブースト）
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = text

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
        var score: [String: Int] = [:]

        // 2-1) 単語スコアリング
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameTypeOrLexicalClass,
            options: options
        ) { tag, range in
            let raw = String(text[range])
            let token = normalizeToken(raw)
            guard isValid(token) else { return true }

            var w = 0
            switch tag {
            case .personalName, .placeName, .organizationName:
                w = 6
            case .noun:
                w = 4
            case .otherWord:
                // 日本語は otherWord が出やすいが、ノイズも多いので控えめ
                w = 1
            default:
                w = 0
            }

            // 文字種ブースト（日本語キーワードらしさ）
            if containsKanji(token) { w += 2 }
            if containsKatakana(token) { w += 1 }

            // prompt に含まれる語は少し優先（“お題に沿う”感が上がる）
            if promptTokens.contains(token) { w += 1 }
            if answerTokens.contains(token) { w += 3 }

            // 問いの文面にありがちな汎用語は弱める。
            if promptTokens.contains(token), !answerTokens.contains(token), isPromptGeneric(token) {
                w = Swift.max(0, w - 3)
            }

            if w > 0 {
                score[token, default: 0] += w
            }
            return true
        }

        // 2-2) 複合語（隣接結合）候補を追加
        // 例: 「研究」「テーマ」→「研究テーマ」
        let compounds = makeCompounds(from: words)
        for c in compounds {
            guard isValid(c) else { continue }
            var w = 3
            if containsKanji(c) { w += 2 }
            if promptTokens.contains(c) { w += 2 }
            score[c, default: 0] += w
        }

        // 3) 何も取れない場合：正規表現フォールバック
        if score.isEmpty {
            let rx = extractByRegex(text: text, max: max)
            return rx.isEmpty ? fallback(answer: a, prompt: p, max: max) : rx
        }

        // 4) ソート（スコア降順 → 長さ降順 → 辞書順）
        let sorted = score.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            if a.key.count != b.key.count { return a.key.count > b.key.count }
            return a.key < b.key
        }.map(\.key)

        // 5) 部分一致の削除（長い語を優先して、短い語の重複を落とす）
        let deduped = removeSubstringDuplicates(sorted)

        return Array(deduped.prefix(max))
    }

    // MARK: - Tokenize

    private static func tokenizeWords(_ text: String) -> [String] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = t

        var result: [String] = []
        tokenizer.enumerateTokens(in: t.startIndex..<t.endIndex) { r, _ in
            result.append(String(t[r]))
            return true
        }
        return result
    }

    /// 隣接トークンを簡易結合して “それっぽい複合語” を作る
    private static func makeCompounds(from words: [String]) -> [String] {
        guard words.count >= 2 else { return [] }
        var out: [String] = []

        for i in 0..<(words.count - 1) {
            let a = words[i]
            let b = words[i + 1]

            // 例: 「の」「は」などは結合しない
            if isWeakParticleLike(a) || isWeakParticleLike(b) { continue }

            // 両方が “名詞っぽい文字種” なら結合候補
            let okA = containsKanji(a) || containsKatakana(a) || containsLatin(a)
            let okB = containsKanji(b) || containsKatakana(b) || containsLatin(b)

            guard okA && okB else { continue }

            let c = normalizeToken(a + b)
            // 長すぎる複合語は避ける（カード表示で崩れやすい）
            if c.count >= 3 && c.count <= 12 {
                out.append(c)
            }
        }
        return out
    }

    private static func isWeakParticleLike(_ s: String) -> Bool {
        // 純ひらがな1〜2文字は助詞になりやすい
        return isAllHiragana(s) && s.count <= 2
    }

    // MARK: - Normalization / Validation

    private static func normalizeText(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeToken(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }

        // 括弧・引用符などの軽い除去
        let trims = CharacterSet(charactersIn: "「」『』（）()[]【】<>〈〉《》“”\"'・")
        t = t.trimmingCharacters(in: trims)

        // 英字が含まれる場合は小文字化
        if t.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
            t = t.lowercased()
        }

        // 末尾の句読点っぽいもの
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "、。・.,!！?？:：;；"))

        return t
    }

    private static func isValid(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return false }

        // URL/メンション断片・メールっぽいもの
        if t.contains("http") || t.contains("://") || t.contains("@") { return false }

        // 数字だけ・記号だけ
        if t.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) { return false }
        if t.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0) }) { return false }

        // 日付・時刻っぽい（例: 2026-01-14 / 1月 / 14日 / 10:30）
        if looksLikeDateOrTime(t) { return false }

        // 純ひらがなはノイズになりやすいので強めに抑制
        // ただし長め（>=4）なら通す余地を残す
        if isAllHiragana(t) && t.count < 4 { return false }

        // ストップワード
        if stopWords.contains(t) { return false }

        // 動詞や抽象語で終わる短語はキーワードとして弱い。
        if (t.hasSuffix("する") || t.hasSuffix("した") || t.hasSuffix("できる") || t.hasSuffix("思う")) && t.count <= 6 {
            return false
        }
        if (t.hasSuffix("こと") || t.hasSuffix("もの")) && t.count <= 4 {
            return false
        }

        return true
    }

    private static func looksLikeDateOrTime(_ s: String) -> Bool {
        // yyyy-mm-dd / yyyy/mm/dd
        if s.range(of: #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}$"#, options: .regularExpression) != nil { return true }
        // hh:mm
        if s.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil { return true }
        // 「2026年」「1月」「14日」など（数字 + 年月日）
        if s.range(of: #"\d+(年|月|日)"#, options: .regularExpression) != nil { return true }
        return false
    }

    // MARK: - Regex fallback

    private static func extractByRegex(text: String, max: Int) -> [String] {
        // 日本語(漢字/ひらがな/カタカナ)連続 or 英数字連続
        let pattern = #"([A-Za-z0-9]{2,}|[一-龥]{2,}|[ぁ-ん]{2,}|[ァ-ヶー]{2,})"#
        let tokens = regexAll(pattern: pattern, in: text).map(normalizeToken).filter { isValid($0) }

        var freq: [String: Int] = [:]
        for w in tokens {
            // 2文字はノイズが出やすいので、正規表現フォールバックでは 3 以上優先
            if w.count <= 2 { continue }
            freq[w, default: 0] += 1
        }

        let sorted = freq.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key.count > b.key.count
        }.map(\.key)

        return Array(removeSubstringDuplicates(sorted).prefix(max))
    }

    private static func regexAll(pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, options: [], range: range).compactMap { m in
            guard let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    // MARK: - Dedup

    /// 長い語を優先し、短い語が長い語の部分文字列なら落とす
    private static func removeSubstringDuplicates(_ tokens: [String]) -> [String] {
        var kept: [String] = []
        for t in tokens {
            if kept.contains(where: { $0.contains(t) && $0.count > t.count }) {
                continue
            }
            // 逆に、既に短い語が入っていて今回の方が長い場合は置き換えたいが、
            // ここでは “長い順に処理” する前提で単純化
            kept.append(t)
        }
        return kept
    }

    // MARK: - Fallback

    private static func fallback(answer: String, prompt: String, max: Int) -> [String] {
        let source = answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? prompt : answer
        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return [] }

        // 回答を優先してざっくり分割。
        let parts = s
            .split(whereSeparator: { $0.isWhitespace || $0 == "、" || $0 == "。" || $0 == "\n" })
            .map(String.init)
            .map(normalizeToken)
            .filter { isValid($0) }

        if !parts.isEmpty {
            return Array(parts.prefix(max))
        }
        // 最終手段として prompt を利用。
        let promptParts = p
            .split(whereSeparator: { $0.isWhitespace || $0 == "、" || $0 == "。" || $0 == "\n" })
            .map(String.init)
            .map(normalizeToken)
            .filter { isValid($0) }
        return Array(promptParts.prefix(max))
    }

    private static func isPromptGeneric(_ token: String) -> Bool {
        promptGenericWords.contains(token)
    }

    // MARK: - Character class helpers

    private static func containsKanji(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) }
    }

    private static func containsKatakana(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x30A0...0x30FF).contains(Int($0.value)) }
    }

    private static func containsLatin(_ s: String) -> Bool {
        s.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.isASCII }
    }

    private static func isAllHiragana(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.unicodeScalars.allSatisfy { (0x3040...0x309F).contains(Int($0.value)) }
    }

    // MARK: - Stopwords

    private static let stopWords: Set<String> = [
        // JP
        "これ","それ","あれ","ここ","そこ","もの","こと",
        "今日","昨日","明日","自分","私","僕","あなた","あなたなら","あなたも",
        "出来事","質問","回答","要約","キーワード","一言","感情","気持ち",
        "次","ひとつ","どれ","どこ","なに","何","どう","どんな","なぜ","いつ","誰",
        "する","した","して","いる","ある","なる",
        "です","ます","ため","よう","ので","から","まで",
        "そして","しかし","でも","また","あと","など","なんか",
        "今回","最近","感じ","一緒","本当","全部",
        // EN (最低限)
        "the","a","an","and","or","to","of","in","on","for","with","as",
        "is","are","was","were","be","been","it","this","that","i","you","we","they"
    ]

    private static let promptGenericWords: Set<String> = [
        "今日","出来事","感情","気持ち","要約","キーワード","一言","視点","自分","明日","行動","質問"
    ]
}
