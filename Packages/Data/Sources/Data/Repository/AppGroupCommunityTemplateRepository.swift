import Foundation
import Domain

public final class AppGroupCommunityTemplateRepository: CommunityTemplateRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let communitiesKey = "MyDailyPhrase.communities.templates.v1"
    private let responsesKey = "MyDailyPhrase.communities.responses.v1"
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let forceSynchronizeOnWrite: Bool

    public init(appGroupID: String, forceSynchronizeOnWrite: Bool = false) {
        self.forceSynchronizeOnWrite = forceSynchronizeOnWrite
        if let defaults = UserDefaults(suiteName: appGroupID) {
            self.defaults = defaults
        } else {
            self.defaults = .standard
            assertionFailure("AppGroup suiteName not found: \(appGroupID). Fallback to .standard.")
        }
    }

    public func listCommunities() -> [CommunityTemplate] {
        withLock {
            loadCommunities()
        }
    }

    public func community(id: String) -> CommunityTemplate? {
        withLock {
            loadCommunities().first { $0.id == id }
        }
    }

    public func saveCommunity(_ community: CommunityTemplate) {
        withLock {
            var community = community
            community.normalize()
            var communities = loadCommunities()
            if let index = communities.firstIndex(where: { $0.id == community.id }) {
                communities[index] = community
            } else {
                communities.append(community)
            }
            storeCommunities(communities)
        }
    }

    public func deleteCommunity(id: String) {
        withLock {
            let communities = loadCommunities().filter { $0.id != id }
            let responses = loadResponses().filter { $0.communityId != id }
            storeCommunities(communities)
            storeResponses(responses)
        }
    }

    public func setJoined(_ isJoined: Bool, communityId: String, joinedAt: Date?) {
        withLock {
            var communities = loadCommunities()
            guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
            communities[index].isJoined = isJoined
            communities[index].joinedAt = isJoined ? (joinedAt ?? communities[index].joinedAt ?? Date()) : nil
            communities[index].normalize()
            storeCommunities(communities)
        }
    }

    public func listResponses() -> [CommunityResponse] {
        withLock {
            loadResponses()
        }
    }

    public func response(communityId: String, promptKey: String) -> CommunityResponse? {
        withLock {
            loadResponses().first {
                $0.communityId == communityId && $0.promptKey == promptKey
            }
        }
    }

    public func saveResponse(_ response: CommunityResponse) {
        withLock {
            var response = response
            response.normalize()
            var responses = loadResponses()
            if let index = responses.firstIndex(where: { $0.id == response.id }) {
                responses[index] = response
            } else {
                responses.append(response)
            }
            storeResponses(responses)
        }
    }

    public func deleteResponse(communityId: String, promptKey: String) {
        withLock {
            let responses = loadResponses().filter {
                !($0.communityId == communityId && $0.promptKey == promptKey)
            }
            storeResponses(responses)
        }
    }

    private func loadCommunities() -> [CommunityTemplate] {
        guard let data = defaults.data(forKey: communitiesKey) else {
            return []
        }
        guard let communities = try? decoder.decode([CommunityTemplate].self, from: data) else {
            return []
        }
        return communities.map {
            var community = $0
            community.normalize()
            return community
        }
    }

    private func loadResponses() -> [CommunityResponse] {
        guard let data = defaults.data(forKey: responsesKey) else {
            return []
        }
        guard let responses = try? decoder.decode([CommunityResponse].self, from: data) else {
            return []
        }
        return responses.map {
            var response = $0
            response.normalize()
            return response
        }
    }

    private func storeCommunities(_ communities: [CommunityTemplate]) {
        let cleaned = communities.map {
            var community = $0
            community.normalize()
            return community
        }
        guard let data = try? encoder.encode(cleaned) else { return }
        defaults.set(data, forKey: communitiesKey)
        synchronizeIfNeeded()
    }

    private func storeResponses(_ responses: [CommunityResponse]) {
        let cleaned = responses.map {
            var response = $0
            response.normalize()
            return response
        }
        guard let data = try? encoder.encode(cleaned) else { return }
        defaults.set(data, forKey: responsesKey)
        synchronizeIfNeeded()
    }

    private func synchronizeIfNeeded() {
        if forceSynchronizeOnWrite {
            defaults.synchronize()
        }
    }

    @inline(__always)
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
