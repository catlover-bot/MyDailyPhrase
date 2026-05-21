import Foundation
import Domain

extension AppGroupUserProfileRepository: ProfileRepository {}
extension AppGroupCommunityTemplateRepository: CommunityRepository {}

public final class LocalSocialConnectionRepository: SocialConnectionRepository, @unchecked Sendable {
    private let recommendedProfilesProvider: @Sendable () -> [SocialUserProfileSummary]

    public init(
        recommendedProfilesProvider: @escaping @Sendable () -> [SocialUserProfileSummary]
    ) {
        self.recommendedProfilesProvider = recommendedProfilesProvider
    }

    public var mode: SocialBackendMode { .localFallback }
    public var isBackendEnabled: Bool { false }

    public func listRecommendedProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let following = Set(profile.followingUserIDs)
        let blocked = Set(profile.blockedUserIDs)
        return recommendedProfilesProvider()
            .filter { !following.contains($0.id) }
            .filter { !blocked.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func listFollowingProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let following = Set(profile.followingUserIDs)
        let blocked = Set(profile.blockedUserIDs)
        return recommendedProfilesProvider()
            .filter { following.contains($0.id) }
            .filter { !blocked.contains($0.id) }
    }

    public func listFollowerPreviewProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let blocked = Set(profile.blockedUserIDs)
        return recommendedProfilesProvider()
            .filter(\.isLocalOnly)
            .filter { !blocked.contains($0.id) }
            .prefix(2)
            .map { $0 }
    }

    public func listMutualFollowProfiles(for profile: UserProfile) -> [SocialUserProfileSummary] {
        let following = Set(profile.followingUserIDs)
        let followers = Set(listFollowerPreviewProfiles(for: profile).map(\.id))
        let mutual = following.intersection(followers)
        return recommendedProfilesProvider()
            .filter { mutual.contains($0.id) }
            .filter { !profile.blockedUserIDs.contains($0.id) }
    }

    public func canStartDirectMessage(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool {
        guard target.supportsMutualDM else { return false }
        guard !profile.blockedUserIDs.contains(target.id) else { return false }
        guard profile.followingUserIDs.contains(target.id) else { return false }
        return listFollowerPreviewProfiles(for: profile).contains { $0.id == target.id }
    }
}

public final class LocalDMRepository: DMRepository, @unchecked Sendable {
    private let profileRepository: UserProfileRepository

    public init(profileRepository: UserProfileRepository) {
        self.profileRepository = profileRepository
    }

    public func listThreads(for userID: String) -> [DirectMessageConversation] {
        guard profileRepository.getMyProfile()?.userId == userID else { return [] }
        return profileRepository.getMyProfile()?.dmConversations ?? []
    }

    public func thread(id: String, for userID: String) -> DirectMessageConversation? {
        listThreads(for: userID).first { $0.id == id || $0.participantUserID == id }
    }

    public func saveThread(_ thread: DirectMessageConversation, for userID: String) {
        guard profileRepository.getMyProfile()?.userId == userID else { return }
        _ = profileRepository.mutateMyProfile(
            { profile in
                var cleaned = thread
                cleaned.normalize()
                profile.dmConversations.removeAll { $0.id == cleaned.id || $0.participantUserID == cleaned.participantUserID }
                profile.dmConversations.insert(cleaned, at: 0)
            },
            makeIfMissing: { UserProfile(userId: userID, displayName: "Me") }
        )
    }

    public func deleteThread(id: String, for userID: String) {
        guard profileRepository.getMyProfile()?.userId == userID else { return }
        _ = profileRepository.mutateMyProfile(
            { profile in
                profile.dmConversations.removeAll { $0.id == id || $0.participantUserID == id }
            },
            makeIfMissing: { UserProfile(userId: userID, displayName: "Me") }
        )
    }

    public func canStartThread(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool {
        target.supportsMutualDM
            && profile.followingUserIDs.contains(target.id)
            && !profile.blockedUserIDs.contains(target.id)
    }
}

public final class AppGroupReportRepository: ReportRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let reportsKey = "MyDailyPhrase.social.reports.v1"
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(appGroupID: String) {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public func listReports(reporterUserID: String) -> [SocialReport] {
        withLock {
            loadReports()
                .filter { $0.reporterUserID == reporterUserID }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func saveReport(_ report: SocialReport) {
        withLock {
            var cleaned = report
            cleaned.normalize()
            guard !cleaned.reporterUserID.isEmpty, !cleaned.targetID.isEmpty else { return }
            var reports = loadReports()
            reports.removeAll { $0.id == cleaned.id }
            reports.append(cleaned)
            guard let data = try? encoder.encode(reports) else { return }
            defaults.set(data, forKey: reportsKey)
        }
    }

    private func loadReports() -> [SocialReport] {
        guard let data = defaults.data(forKey: reportsKey),
              let reports = try? decoder.decode([SocialReport].self, from: data) else {
            return []
        }
        return reports.map {
            var copy = $0
            copy.normalize()
            return copy
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
