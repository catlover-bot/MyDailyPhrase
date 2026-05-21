import Foundation

public enum SocialBackendMode: String, Codable, CaseIterable, Sendable {
    case localFallback
    case supabase
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

public protocol ProfileRepository: UserProfileRepository {}

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
