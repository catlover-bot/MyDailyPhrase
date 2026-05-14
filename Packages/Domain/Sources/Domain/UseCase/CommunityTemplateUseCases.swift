import Foundation

public struct ListCommunitiesUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction() -> [CommunityTemplate] {
        repo.listCommunities()
    }
}

public struct GetCommunityUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction(id: String) -> CommunityTemplate? {
        repo.community(id: id)
    }
}

public struct SaveCommunityTemplateUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    @discardableResult
    public func callAsFunction(_ community: CommunityTemplate) -> CommunityTemplate {
        var community = community
        community.normalize()
        repo.saveCommunity(community)
        return community
    }
}

public struct DeleteCommunityTemplateUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction(id: String) {
        repo.deleteCommunity(id: id)
    }
}

public struct JoinCommunityUseCase: Sendable {
    private let repo: CommunityTemplateRepository
    private let nowProvider: @Sendable () -> Date

    public init(
        repo: CommunityTemplateRepository,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repo = repo
        self.nowProvider = nowProvider
    }

    public func callAsFunction(communityId: String) {
        repo.setJoined(true, communityId: communityId, joinedAt: nowProvider())
    }
}

public struct LeaveCommunityUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction(communityId: String) {
        repo.setJoined(false, communityId: communityId, joinedAt: nil)
    }
}

public struct ListCommunityResponsesUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction() -> [CommunityResponse] {
        repo.listResponses()
    }
}

public struct GetCommunityResponseUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    public func callAsFunction(communityId: String, promptKey: String) -> CommunityResponse? {
        repo.response(communityId: communityId, promptKey: promptKey)
    }
}

public struct SaveCommunityResponseUseCase: Sendable {
    private let repo: CommunityTemplateRepository

    public init(repo: CommunityTemplateRepository) {
        self.repo = repo
    }

    @discardableResult
    public func callAsFunction(_ response: CommunityResponse) -> CommunityResponse {
        var response = response
        response.normalize()
        repo.saveResponse(response)
        return response
    }
}
