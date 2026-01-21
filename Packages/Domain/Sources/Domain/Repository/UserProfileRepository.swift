import Foundation

public protocol UserProfileRepository: Sendable {
    func getMyProfile() -> UserProfile?
    func saveMyProfile(_ profile: UserProfile)
}
