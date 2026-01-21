import Foundation

public enum CommentLinkCodecError: Error {
    case invalidURL
    case invalidHost
    case missingQueryItem(String)
}

public enum CommentLinkCodec {
    public static let scheme = "mydailyphrase"
    public static let hostComment = "comment"

    public static func encode(_ link: CommentLink) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = hostComment

        var items: [URLQueryItem] = []
        items.append(.init(name: "v", value: String(link.v)))
        items.append(.init(name: "id", value: link.id))
        items.append(.init(name: "text", value: link.text))

        if let to = link.toChallengeId, !to.isEmpty { items.append(.init(name: "toChallengeId", value: to)) }
        if let room = link.room, !room.isEmpty { items.append(.init(name: "room", value: room)) }
        if let chain = link.chainId, !chain.isEmpty { items.append(.init(name: "chainId", value: chain)) }

        items.append(.init(name: "fromId", value: link.fromId))
        items.append(.init(name: "fromName", value: link.fromName))

        c.queryItems = items
        return c.url
    }

    public static func decode(_ url: URL) throws -> CommentLink {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw CommentLinkCodecError.invalidURL }
        guard c.scheme == scheme, c.host == hostComment else { throw CommentLinkCodecError.invalidHost }

        let q: [String: String] = Dictionary(
            uniqueKeysWithValues: (c.queryItems ?? []).compactMap { item in
                guard let v = item.value else { return nil }
                return (item.name, v)
            }
        )

        func req(_ k: String) throws -> String {
            guard let v = q[k], !v.isEmpty else { throw CommentLinkCodecError.missingQueryItem(k) }
            return v
        }

        let v = Int(q["v"] ?? "1") ?? 1

        return CommentLink(
            v: v,
            id: try req("id"),
            text: try req("text"),
            toChallengeId: q["toChallengeId"],
            room: q["room"],
            chainId: q["chainId"],
            fromId: try req("fromId"),
            fromName: try req("fromName")
        )
    }
}
