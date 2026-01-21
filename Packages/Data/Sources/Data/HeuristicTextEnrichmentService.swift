import Foundation
import Domain

public final class HeuristicTextEnrichmentService: TextEnrichmentService, @unchecked Sendable {
    public init() {}

    public func enrich(prompt: String, answer: String, locale: Locale) -> ReflectionArtifact {
        let cleanedAnswer = normalize(answer)
        let cleanedPrompt = normalize(prompt)

        let title = makeTitle(prompt: cleanedPrompt, answer: cleanedAnswer)
        let summary = makeSummary(answer: cleanedAnswer, maxChars: 90)

        // ✅ キーワード抽出は KeywordExtractor に一本化（品質改善・重複回避）
        let keywords = KeywordExtractor.extract(
            prompt: cleanedPrompt,
            answer: cleanedAnswer,
            max: 8,
            locale: locale
        )

        let moods = detectMoodTags(text: cleanedAnswer)

        return ReflectionArtifact(
            title: title,
            summary: summary,
            keywords: keywords,
            moodTags: moods
        )
    }

    // MARK: - Core building blocks

    private func makeTitle(prompt: String, answer: String) -> String {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return "未回答" }

        // 1) 15文字以下ならそのまま“題名”扱い
        if a.count <= 15 { return a }

        // 2) 句点/改行で最初の一文
        if let firstSentence = firstSentence(of: a), firstSentence.count >= 6 {
            return trimTo(firstSentence, max: 24)
        }

        // 3) お題の先頭を絡める（“作品”っぽい）
        let p = trimTo(prompt, max: 16)
        return trimTo("「\(p)」— \(a)", max: 28)
    }

    private func makeSummary(answer: String, maxChars: Int) -> String {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return "（まだ回答がありません）" }

        // 句点/改行で区切れるなら前半を要約扱い
        if let first = firstSentence(of: a), first.count >= 12 {
            return trimTo(first, max: maxChars)
        }

        return trimTo(a, max: maxChars)
    }

    // MARK: - Mood tags

    private func detectMoodTags(text: String) -> [String] {
        let t = normalize(text)

        var tags: [String] = []
        func has(_ keywords: [String]) -> Bool { keywords.contains { t.contains($0) } }

        if has(["嬉", "うれし", "楽", "たのし", "最高", "幸せ", "よかった", "感謝"]) { tags.append("喜び") }
        if has(["悲", "かなし", "つら", "辛", "寂", "さび", "泣"]) { tags.append("哀しみ") }
        if has(["怒", "むか", "ムカ", "腹立", "許せ"]) { tags.append("怒り") }
        if has(["不安", "心配", "こわ", "怖", "緊張", "焦"]) { tags.append("不安") }
        if has(["疲", "眠", "だる", "しんど"]) { tags.append("疲れ") }
        if has(["挑戦", "がんば", "頑張", "努力", "成長", "学"]) { tags.append("挑戦") }

        if tags.isEmpty { tags.append("日常") }
        return Array(tags.prefix(3))
    }

    // MARK: - Helpers

    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimTo(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        let idx = s.index(s.startIndex, offsetBy: max)
        return String(s[..<idx]) + "…"
    }

    private func firstSentence(of s: String) -> String? {
        let separators: [Character] = ["。", "\n", ".", "！", "!", "？", "?"]
        if let i = s.firstIndex(where: { separators.contains($0) }) {
            let head = String(s[..<i])
            let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
