import Foundation

public enum SocialBackendMode: String, Codable, CaseIterable, Sendable {
    case localFallback
    case supabase
}

public enum ProfileSyncStatus: String, Codable, CaseIterable, Sendable {
    case localFallback
    case skippedSignedOut
    case idle
    case syncing
    case synced
    case failed
}

public struct ProfileOwnerIdentity: Codable, Equatable, Sendable {
    public var userID: String
    public var provider: String
    public var providerUserID: String
    public var email: String?

    public init(
        userID: String,
        provider: String,
        providerUserID: String,
        email: String? = nil
    ) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.providerUserID = providerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
    }

    public var isUsable: Bool {
        !userID.isEmpty && !provider.isEmpty && !providerUserID.isEmpty
    }

    public init?(profile: UserProfile, email: String? = nil) {
        guard let provider = profile.linkedAuthProvider,
              let providerUserID = profile.linkedAuthUserId else {
            return nil
        }
        self.init(
            userID: profile.userId,
            provider: provider,
            providerUserID: providerUserID,
            email: email
        )
        guard isUsable else { return nil }
    }
}

public struct ProfileSyncDiagnostics: Codable, Equatable, Sendable {
    public var status: ProfileSyncStatus
    public var lastErrorMessage: String?
    public var lastSyncAt: Date?
    public var lastAttemptAt: Date?
    public var lastSyncedUserID: String?

    public init(
        status: ProfileSyncStatus = .localFallback,
        lastErrorMessage: String? = nil,
        lastSyncAt: Date? = nil,
        lastAttemptAt: Date? = nil,
        lastSyncedUserID: String? = nil
    ) {
        self.status = status
        self.lastErrorMessage = lastErrorMessage
        self.lastSyncAt = lastSyncAt
        self.lastAttemptAt = lastAttemptAt
        self.lastSyncedUserID = lastSyncedUserID
    }

    public static let localFallback = ProfileSyncDiagnostics()
}

public enum SocialReportTargetKind: String, Codable, CaseIterable, Sendable {
    case user
    case community
    case dmMessage
}

public enum SocialReportReason: String, Codable, CaseIterable, Sendable {
    case spam
    case harassment
    case unsafeContent
    case impersonation
    case other
}

public struct SocialReport: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var reporterUserID: String
    public var targetKind: SocialReportTargetKind
    public var targetID: String
    public var reason: SocialReportReason
    public var note: String?
    public var createdAt: Date
    public var isLocalOnly: Bool

    public init(
        id: String = UUID().uuidString,
        reporterUserID: String,
        targetKind: SocialReportTargetKind,
        targetID: String,
        reason: SocialReportReason,
        note: String? = nil,
        createdAt: Date = Date(),
        isLocalOnly: Bool = true
    ) {
        self.id = id
        self.reporterUserID = reporterUserID
        self.targetKind = targetKind
        self.targetID = targetID
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
        self.isLocalOnly = isLocalOnly
        normalize()
    }

    public mutating func normalize(maxNoteLength: Int = 280) {
        id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty {
            id = UUID().uuidString
        }
        reporterUserID = reporterUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        targetID = targetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedNote, !trimmedNote.isEmpty {
            note = String(trimmedNote.prefix(maxNoteLength))
        } else {
            note = nil
        }
    }
}

public protocol ProfileRepository: UserProfileRepository {
    var mode: SocialBackendMode { get }
    var isBackendEnabled: Bool { get }

    func profileSyncDiagnostics() -> ProfileSyncDiagnostics
    func fetchCurrentUserProfile(owner: ProfileOwnerIdentity) async throws -> UserProfile?
    func upsertCurrentUserProfile(_ profile: UserProfile, owner: ProfileOwnerIdentity) async throws -> UserProfile
    func updateDisplayName(_ displayName: String, owner: ProfileOwnerIdentity) async throws -> UserProfile
    func updateBio(_ bio: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile
    func updateAvatarSymbol(_ avatarSymbol: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile
    func updateInterestTags(_ interestTags: [String], owner: ProfileOwnerIdentity) async throws -> UserProfile
}

public extension ProfileRepository {
    var mode: SocialBackendMode { .localFallback }
    var isBackendEnabled: Bool { false }

    func profileSyncDiagnostics() -> ProfileSyncDiagnostics {
        .localFallback
    }

    func fetchCurrentUserProfile(owner: ProfileOwnerIdentity) async throws -> UserProfile? {
        guard owner.isUsable else { return nil }
        return getMyProfile()
    }

    func upsertCurrentUserProfile(_ profile: UserProfile, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        saveMyProfile(profile)
        return profile
    }

    func updateDisplayName(_ displayName: String, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        mutateMyProfile(
            { $0.displayName = displayName },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: displayName) }
        )
    }

    func updateBio(_ bio: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        mutateMyProfile(
            { $0.profileBio = bio },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", profileBio: bio) }
        )
    }

    func updateAvatarSymbol(_ avatarSymbol: String?, owner: ProfileOwnerIdentity) async throws -> UserProfile {
        mutateMyProfile(
            { $0.avatarSymbol = avatarSymbol },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", avatarSymbol: avatarSymbol) }
        )
    }

    func updateInterestTags(_ interestTags: [String], owner: ProfileOwnerIdentity) async throws -> UserProfile {
        mutateMyProfile(
            { $0.interestTags = interestTags },
            makeIfMissing: { UserProfile(userId: owner.userID, displayName: "Me", interestTags: interestTags) }
        )
    }
}

public protocol CommunityRepository: CommunityTemplateRepository {}

public protocol DMRepository: Sendable {
    func listThreads(for userID: String) -> [DirectMessageConversation]
    func thread(id: String, for userID: String) -> DirectMessageConversation?
    func saveThread(_ thread: DirectMessageConversation, for userID: String)
    func deleteThread(id: String, for userID: String)
    func canStartThread(from profile: UserProfile, to target: SocialUserProfileSummary) -> Bool
}

public protocol ReportRepository: Sendable {
    func listReports(reporterUserID: String) -> [SocialReport]
    func saveReport(_ report: SocialReport)
}
