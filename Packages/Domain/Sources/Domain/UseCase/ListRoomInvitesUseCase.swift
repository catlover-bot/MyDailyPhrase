import Foundation

public struct ListRoomInvitesUseCase: Sendable {
    private let events: RoomInviteEventRepository

    public init(events: RoomInviteEventRepository) {
        self.events = events
    }

    public func callAsFunction(box: EventBox) -> [RoomInviteEvent] {
        events.list(box: box).sorted { $0.createdAt > $1.createdAt }
    }
}
