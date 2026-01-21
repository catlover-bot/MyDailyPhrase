import Foundation

public protocol ChallengeEventRepository: Sendable {
    func upsert(_ event: ChallengeEvent)
    func list(box: EventBox) -> [ChallengeEvent]
    func deleteAll()
}
