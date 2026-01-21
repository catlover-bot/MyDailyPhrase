import Foundation

public struct CreateRoomInviteLinkUseCase: Sendable {
    private let profileUC: GetMyProfileUseCase
    private let events: RoomInviteEventRepository

    public init(profileUC: GetMyProfileUseCase, events: RoomInviteEventRepository) {
        self.profileUC = profileUC
        self.events = events
    }

    public func callAsFunction(roomId: String, roomName: String?) -> URL? {
        let me = profileUC()
        let inviteId = UUID().uuidString
        let link = RoomInviteLink(inviteId: inviteId, roomId: roomId, roomName: roomName, fromId: me.userId, fromName: me.displayName)
        let ev = RoomInviteEvent(id: inviteId, box: .outbox, link: link, createdAt: Date())
        events.upsert(ev)
        return RoomLinkCodec.encodeInvite(link)
    }
}
