import Foundation

public protocol RoomInviteEventRepository: Sendable {
    func upsert(_ event: RoomInviteEvent)
    func list(box: EventBox) -> [RoomInviteEvent]
}
