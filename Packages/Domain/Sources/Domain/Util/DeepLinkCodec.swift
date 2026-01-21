import Foundation

public enum MyDailyPhraseDeepLink: Equatable, Sendable {
    case challenge(ChallengeLink)
    case react(ReactionLink)
}

public enum DeepLinkError: Error, Sendable, LocalizedError {
    case invalidScheme(expected: String, actual: String?)
    case invalidHost(actual: String?)
    case missingRequired(String)
    case invalidValue(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidScheme(expected, actual):
            return "invalid scheme. expected=\(expected) actual=\(actual ?? "nil")"
        case let .invalidHost(actual):
            return "invalid host. actual=\(actual ?? "nil")"
        case let .missingRequired(k):
            return "missing required param: \(k)"
        case let .invalidValue(msg):
            return "invalid value: \(msg)"
        }
    }
}

public enum DeepLinkCodec {
    public static let scheme = "mydailyphrase"

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Encode

    public static func makeURL(_ link: ChallengeLink) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "challenge"
        c.queryItems = compactQueryItems([
            ("v", String(link.v)),
            ("id", link.id),
            ("dateKey", link.dateKey),
            ("prompt", link.prompt),
            ("fromId", link.fromId),
            ("fromName", link.fromName),
            ("room", link.room),
            ("chainId", link.chainId),
            ("createdAt", isoFrac.string(from: link.createdAt))
        ])
        return c.url
    }

    public static func makeURL(_ link: ReactionLink) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "react"
        c.queryItems = compactQueryItems([
            ("v", String(link.v)),
            ("id", link.id),
            ("emoji", link.emoji),
            ("toChallengeId", link.toChallengeId),
            ("fromId", link.fromId),
            ("fromName", link.fromName),
            ("room", link.room),
            ("chainId", link.chainId),
            ("createdAt", isoFrac.string(from: link.createdAt))
        ])
        return c.url
    }

    // MARK: - Decode

    public static func parse(_ url: URL) throws -> MyDailyPhraseDeepLink {
        guard url.scheme == scheme else {
            throw DeepLinkError.invalidScheme(expected: scheme, actual: url.scheme)
        }

        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = comp?.host

        switch host {
        case "challenge":
            return .challenge(try parseChallenge(url))
        case "react":
            return .react(try parseReact(url))
        default:
            throw DeepLinkError.invalidHost(actual: host)
        }
    }

    private static func parseChallenge(_ url: URL) throws -> ChallengeLink {
        let q = queryDict(url)

        let v = Int(q["v"] ?? "1") ?? 1
        let id = try require(q, "id")
        let dateKey = try require(q, "dateKey")
        let prompt = try require(q, "prompt")
        let fromId = try require(q, "fromId")
        let fromName = try require(q, "fromName")
        let room = q["room"]
        let chainId = q["chainId"]
        let createdAt = parseISO(q["createdAt"]) ?? Date()

        return ChallengeLink(
            v: v,
            id: id,
            dateKey: dateKey,
            prompt: prompt,
            fromId: fromId,
            fromName: fromName,
            room: room,
            chainId: chainId,
            createdAt: createdAt
        )
    }

    private static func parseReact(_ url: URL) throws -> ReactionLink {
        let q = queryDict(url)

        let v = Int(q["v"] ?? "1") ?? 1
        let id = try require(q, "id")
        let emoji = try require(q, "emoji")
        let fromId = try require(q, "fromId")
        let fromName = try require(q, "fromName")

        let toChallengeId = q["toChallengeId"]
        let room = q["room"]
        let chainId = q["chainId"]
        let createdAt = parseISO(q["createdAt"]) ?? Date()

        return ReactionLink(
            v: v,
            id: id,
            emoji: emoji,
            toChallengeId: toChallengeId,
            fromId: fromId,
            fromName: fromName,
            room: room,
            chainId: chainId,
            createdAt: createdAt
        )
    }

    // MARK: - Helpers

    private static func compactQueryItems(_ items: [(String, String?)]) -> [URLQueryItem] {
        items.compactMap { (k, v) in
            guard let v, !v.isEmpty else { return nil }
            return URLQueryItem(name: k, value: v)
        }
    }

    private static func queryDict(_ url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return [:]
        }
        var dict: [String: String] = [:]
        for it in items {
            if let v = it.value { dict[it.name] = v }
        }
        return dict
    }

    private static func require(_ q: [String: String], _ key: String) throws -> String {
        guard let v = q[key], !v.isEmpty else { throw DeepLinkError.missingRequired(key) }
        return v
    }

    private static func parseISO(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = isoFrac.date(from: s) { return d }
        return isoNoFrac.date(from: s)
    }
}
