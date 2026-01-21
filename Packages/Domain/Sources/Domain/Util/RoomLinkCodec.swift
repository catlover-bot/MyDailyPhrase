import Foundation

public enum RoomLinkCodecError: Error {
    case invalidURL
    case invalidHost
    case missingQueryItem(String)
}

public enum RoomLinkCodec {
    public static let scheme = "mydailyphrase"
    public static let hostInvite = "room_invite"
    public static let hostJoin = "room_join"

    // MARK: - Encode

    public static func encodeInvite(_ link: RoomInviteLink) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = hostInvite

        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "v", value: String(link.v)))
        items.append(URLQueryItem(name: "inviteId", value: link.inviteId))
        items.append(URLQueryItem(name: "room", value: link.roomId))
        if let roomName = link.roomName, !roomName.isEmpty {
            items.append(URLQueryItem(name: "roomName", value: roomName))
        }
        items.append(URLQueryItem(name: "fromId", value: link.fromId))
        items.append(URLQueryItem(name: "fromName", value: link.fromName))

        c.queryItems = items
        return c.url
    }

    public static func encodeJoin(_ link: RoomJoinLink) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = hostJoin

        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "v", value: String(link.v)))
        items.append(URLQueryItem(name: "room", value: link.roomId))
        if let roomName = link.roomName, !roomName.isEmpty {
            items.append(URLQueryItem(name: "roomName", value: roomName))
        }
        items.append(URLQueryItem(name: "userId", value: link.userId))
        items.append(URLQueryItem(name: "name", value: link.name))

        c.queryItems = items
        return c.url
    }

    // MARK: - Decode

    public static func decodeInvite(_ url: URL) throws -> RoomInviteLink {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RoomLinkCodecError.invalidURL
        }
        guard c.scheme == scheme, c.host == hostInvite else {
            throw RoomLinkCodecError.invalidHost
        }

        let q: [String: String] = Dictionary(
            uniqueKeysWithValues: (c.queryItems ?? []).compactMap { item in
                guard let v = item.value else { return nil }
                return (item.name, v)
            }
        )

        func req(_ k: String) throws -> String {
            guard let v = q[k], !v.isEmpty else { throw RoomLinkCodecError.missingQueryItem(k) }
            return v
        }

        let v = Int(q["v"] ?? "1") ?? 1
        return RoomInviteLink(
            v: v,
            inviteId: try req("inviteId"),
            roomId: try req("room"),
            roomName: q["roomName"],
            fromId: try req("fromId"),
            fromName: try req("fromName")
        )
    }

    public static func decodeJoin(_ url: URL) throws -> RoomJoinLink {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RoomLinkCodecError.invalidURL
        }
        guard c.scheme == scheme, c.host == hostJoin else {
            throw RoomLinkCodecError.invalidHost
        }

        let q: [String: String] = Dictionary(
            uniqueKeysWithValues: (c.queryItems ?? []).compactMap { item in
                guard let v = item.value else { return nil }
                return (item.name, v)
            }
        )

        func req(_ k: String) throws -> String {
            guard let v = q[k], !v.isEmpty else { throw RoomLinkCodecError.missingQueryItem(k) }
            return v
        }

        let v = Int(q["v"] ?? "1") ?? 1
        return RoomJoinLink(
            v: v,
            roomId: try req("room"),
            roomName: q["roomName"],
            userId: try req("userId"),
            name: try req("name")
        )
    }
}
