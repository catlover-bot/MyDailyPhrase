import Foundation

public protocol CommunityTemplateRepository: Sendable {
    func listCommunities() -> [CommunityTemplate]
    func community(id: String) -> CommunityTemplate?
    func saveCommunity(_ community: CommunityTemplate)
    func deleteCommunity(id: String)
    func setJoined(_ isJoined: Bool, communityId: String, joinedAt: Date?)

    func listResponses() -> [CommunityResponse]
    func response(communityId: String, promptKey: String) -> CommunityResponse?
    func saveResponse(_ response: CommunityResponse)
    func deleteResponse(communityId: String, promptKey: String)
}
