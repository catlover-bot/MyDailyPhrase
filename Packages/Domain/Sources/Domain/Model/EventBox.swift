import Foundation

public enum EventBox: String, Codable, Sendable {
    case inbox
    case outbox
}
