import Foundation

public struct Entry: Codable, Equatable, Sendable {
    public let dateKey: String
    public let prompt: Prompt
    public var answer: String?
    public var isFavorite: Bool

    public init(dateKey: String, prompt: Prompt, answer: String? = nil, isFavorite: Bool = false) {
        self.dateKey = dateKey
        self.prompt = prompt
        self.answer = answer
        self.isFavorite = isFavorite
    }

    // 既存保存データ互換（isFavorite が無い JSON を読めるようにする）
    private enum CodingKeys: String, CodingKey {
        case dateKey
        case prompt
        case answer
        case isFavorite
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dateKey = try c.decode(String.self, forKey: .dateKey)
        self.prompt = try c.decode(Prompt.self, forKey: .prompt)
        self.answer = try c.decodeIfPresent(String.self, forKey: .answer)
        self.isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dateKey, forKey: .dateKey)
        try c.encode(prompt, forKey: .prompt)
        try c.encodeIfPresent(answer, forKey: .answer)
        try c.encode(isFavorite, forKey: .isFavorite)
    }
}
