import Foundation

public struct ReceiveRoomInviteLinkUseCase: Sendable {
    private let events: RoomInviteEventRepository

    public init(events: RoomInviteEventRepository) {
        self.events = events
    }

    @discardableResult
    public func callAsFunction(url: URL) throws -> RoomInviteEvent {
        let link = try RoomLinkCodec.decodeInvite(url)
        let ev = RoomInviteEvent(id: link.inviteId, box: .inbox, link: link, createdAt: Date())
        events.upsert(ev)
        return ev
    }
}
