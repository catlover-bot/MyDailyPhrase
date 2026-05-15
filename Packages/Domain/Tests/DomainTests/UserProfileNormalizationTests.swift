import Foundation
import Testing
@testable import Domain

@Suite("UserProfile normalization")
struct UserProfileNormalizationTests {

    @Test("displayName trims, collapses whitespaces and clips length")
    func displayNameFormatting() {
        let longTail = String(repeating: "x", count: UserProfile.maxDisplayNameLength + 10)
        var p = UserProfile(
            userId: "u-name",
            displayName: "  Alice \n\t Bob   \(longTail)  "
        )

        p.normalize()

        #expect(!p.displayName.contains("\n"))
        #expect(!p.displayName.contains("\t"))
        #expect(p.displayName.count == UserProfile.maxDisplayNameLength)
    }

    @Test("empty displayName becomes Me")
    func emptyDisplayNameFallback() {
        var p = UserProfile(userId: "u-empty", displayName: "   \n\t ")
        p.normalize()

        #expect(p.displayName == "Me")
    }

    @Test("unknown decoration ids are removed and selected id falls back to classic")
    func unknownDecorationIDsAreDropped() {
        var p = UserProfile(
            userId: "u-deco",
            displayName: "Me",
            selectedDecorationId: "unknown-selected",
            ownedDecorationIds: ["classic", "unknown-1"],
            ownedDecorationCounts: [
                "classic": 1,
                "unknown-1": 3,
                "unknown-2": 1
            ]
        )

        p.normalize()

        #expect(p.selectedDecorationId == CardDecorationCatalog.classicId)
        #expect(p.ownedDecorationCounts["unknown-1"] == nil)
        #expect(p.ownedDecorationCounts["unknown-2"] == nil)
        #expect((p.ownedDecorationCounts[CardDecorationCatalog.classicId] ?? 0) >= 1)
    }

    @Test("gacha counters are clamped and invalid date key is cleared")
    func gachaFieldsAreClamped() {
        var p = UserProfile(
            userId: "u-clamp",
            displayName: "Me",
            decorationShards: -10,
            pityCount: -1,
            gachaTickets: -99,
            lastFreeTicketDateKey: "2026-02-14"
        )
        p.normalize()

        #expect(p.decorationShards == 0)
        #expect(p.pityCount == 0)
        #expect(p.gachaTickets == 0)
        #expect(p.lastFreeTicketDateKey == nil)
    }

    @Test("UpdateMyProfileUseCase persists normalized displayName")
    func updateUseCaseNormalizesDisplayName() {
        let repo = InMemoryProfileRepo()
        repo.saveMyProfile(UserProfile(userId: "u-upd", displayName: "Old Name"))

        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-upd" })
        let updated = update(displayName: "  \u{0000}   ")

        #expect(updated.displayName == "Me")
        #expect(repo.getMyProfile()?.displayName == "Me")
    }

    @Test("linked auth is cleared when provider/userId pair is incomplete")
    func linkedAuthNeedsProviderAndUserIdPair() {
        var p = UserProfile(
            userId: "u-auth",
            displayName: "Me",
            linkedAuthProvider: "apple",
            linkedAuthUserId: "   "
        )
        p.normalize()

        #expect(p.linkedAuthProvider == nil)
        #expect(p.linkedAuthUserId == nil)
        #expect(p.linkedAuthAt == nil)
    }

    @Test("linked auth provider only accepts known values")
    func linkedAuthProviderWhitelist() {
        var p = UserProfile(
            userId: "u-auth",
            displayName: "Me",
            linkedAuthProvider: "line",
            linkedAuthUserId: "line-user-1"
        )
        p.normalize()

        #expect(p.linkedAuthProvider == nil)
        #expect(p.linkedAuthUserId == nil)
        #expect(p.linkedAuthAt == nil)
    }

    @Test("auth audit trail is sorted and capped")
    func authAuditTrailIsSortedAndCapped() {
        let old = AuthAuditEvent(
            kind: .linked,
            provider: "apple",
            authUserIdHint: "***old",
            message: "old",
            occurredAt: Date(timeIntervalSince1970: 100)
        )
        let new = AuthAuditEvent(
            kind: .unlinked,
            provider: "apple",
            authUserIdHint: "***new",
            message: "new",
            occurredAt: Date(timeIntervalSince1970: 200)
        )

        var many = [AuthAuditEvent]()
        for i in 0..<(UserProfile.maxAuthAuditTrailCount + 2) {
            many.append(
                AuthAuditEvent(
                    kind: .linked,
                    provider: "apple",
                    authUserIdHint: "***\(i)",
                    message: "ev-\(i)",
                    occurredAt: Date(timeIntervalSince1970: TimeInterval(i))
                )
            )
        }
        many.append(old)
        many.append(new)

        var p = UserProfile(
            userId: "u-audit",
            displayName: "Me",
            authAuditTrail: many
        )
        p.normalize()

        #expect(p.authAuditTrail.count == UserProfile.maxAuthAuditTrailCount)
        #expect((p.authAuditTrail.first?.occurredAt ?? .distantPast) >= (p.authAuditTrail.last?.occurredAt ?? .distantFuture))
    }

    @Test("legacy auth audit migrates into security audit when missing")
    func legacyAuthAuditMigratesToSecurityAudit() {
        let auth = AuthAuditEvent(
            kind: .linked,
            provider: "apple",
            authUserIdHint: "***999999",
            message: "legacy"
        )
        let p = UserProfile(
            userId: "u-migrate",
            displayName: "Me",
            authAuditTrail: [auth],
            securityAuditTrail: []
        )

        #expect(p.securityAuditTrail.count == 1)
        #expect(p.securityAuditTrail.first?.category == .auth)
        #expect(p.securityAuditTrail.first?.kind == .authLinked)
    }

    @Test("UpdateMyProfileUseCase can set and clear linked auth")
    func updateUseCaseCanSetAndClearLinkedAuth() {
        let repo = InMemoryProfileRepo()
        repo.saveMyProfile(UserProfile(userId: "u-auth-upd", displayName: "Me"))

        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-auth-upd" })
        let linked = update(linkedAuthProvider: "apple", linkedAuthUserId: "apple-user-1")

        #expect(linked.linkedAuthProvider == "apple")
        #expect(linked.linkedAuthUserId == "apple-user-1")
        #expect(linked.linkedAuthAt != nil)

        let cleared = update(clearLinkedAuth: true)
        #expect(cleared.linkedAuthProvider == nil)
        #expect(cleared.linkedAuthUserId == nil)
        #expect(cleared.linkedAuthAt == nil)
    }

    @Test("linked auth provider replacement requires explicit opt-in")
    func updateUseCaseBlocksProviderReplacementByDefault() {
        let repo = InMemoryProfileRepo()
        repo.saveMyProfile(
            UserProfile(
                userId: "u-auth-replace",
                displayName: "Me",
                linkedAuthProvider: "apple",
                linkedAuthUserId: "apple-u"
            )
        )

        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-auth-replace" })
        let blocked = update(linkedAuthProvider: "google", linkedAuthUserId: "google-u")
        #expect(blocked.linkedAuthProvider == "apple")
        #expect(blocked.linkedAuthUserId == "apple-u")

        let replaced = update(
            linkedAuthProvider: "google",
            linkedAuthUserId: "google-u",
            allowLinkedAuthProviderReplacement: true
        )
        #expect(replaced.linkedAuthProvider == "google")
        #expect(replaced.linkedAuthUserId == "google-u")
    }

    @Test("UpdateMyProfileUseCase appends auth audit event")
    func updateUseCaseAppendsAuthAuditEvent() {
        let repo = InMemoryProfileRepo()
        repo.saveMyProfile(UserProfile(userId: "u-audit-upd", displayName: "Me"))

        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-audit-upd" })
        let appended = update(
            appendAuthAuditEvent: AuthAuditEvent(
                kind: .linked,
                provider: "apple",
                authUserIdHint: "***123456",
                message: "linked"
            )
        )

        #expect(appended.authAuditTrail.count == 1)
        #expect(appended.authAuditTrail.first?.kind == .linked)
        #expect(appended.securityAuditTrail.count == 1)
        #expect(appended.securityAuditTrail.first?.kind == .authLinked)
    }

    @Test("social graph and DM state normalize safely")
    func socialGraphNormalizesSafely() {
        var profile = UserProfile(
            userId: "me",
            displayName: "Me",
            followingUserIDs: ["friend-a", "friend-a", "me", "friend-b"],
            blockedUserIDs: ["friend-b", "friend-b"],
            reportedUserIDs: ["friend-c", "friend-c", "me"],
            dmConversations: [
                DirectMessageConversation(
                    participantUserID: "friend-a",
                    participantDisplayName: "Friend A",
                    messages: [
                        DirectMessageMessage(sender: .me, body: " hello ", sentAt: Date(timeIntervalSince1970: 2))
                    ]
                ),
                DirectMessageConversation(
                    participantUserID: "friend-b",
                    participantDisplayName: "Friend B",
                    messages: [
                        DirectMessageMessage(sender: .me, body: "blocked", sentAt: Date(timeIntervalSince1970: 1))
                    ]
                )
            ]
        )

        profile.normalize()

        #expect(profile.followingUserIDs == ["friend-a"])
        #expect(profile.blockedUserIDs == ["friend-b"])
        #expect(profile.reportedUserIDs == ["friend-c"])
        #expect(profile.dmConversations.count == 1)
        #expect(profile.dmConversations.first?.participantUserID == "friend-a")
        #expect(profile.dmConversations.first?.messages.first?.body == "hello")
    }

    @Test("UpdateMyProfileUseCase appends and replaces security audit trail")
    func updateUseCaseAppendsAndReplacesSecurityAuditTrail() {
        let repo = InMemoryProfileRepo()
        repo.saveMyProfile(UserProfile(userId: "u-security-upd", displayName: "Me"))

        let update = UpdateMyProfileUseCase(repo: repo, makeId: { "u-security-upd" })
        let appended = update(
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .gacha,
                kind: .gachaDrawCompleted,
                severity: .info,
                title: "draw",
                detail: "ok"
            )
        )
        #expect(appended.securityAuditTrail.count == 1)
        #expect(appended.securityAuditTrail.first?.kind == .gachaDrawCompleted)

        let replaced = update(
            securityAuditTrail: [
                SecurityAuditEvent(
                    category: .community,
                    kind: .communityRoomJoined,
                    severity: .info,
                    title: "join",
                    detail: "room-1"
                )
            ]
        )
        #expect(replaced.securityAuditTrail.count == 1)
        #expect(replaced.securityAuditTrail.first?.kind == .communityRoomJoined)
    }
}

private final class InMemoryProfileRepo: UserProfileRepository, @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var profile: UserProfile?

    func getMyProfile() -> UserProfile? {
        withLock { profile }
    }

    func saveMyProfile(_ profile: UserProfile) {
        withLock {
            self.profile = profile
        }
    }

    @discardableResult
    func mutateMyProfile(
        _ mutate: @Sendable (inout UserProfile) -> Void,
        makeIfMissing: @Sendable () -> UserProfile
    ) -> UserProfile {
        withLock {
            var p = profile ?? makeIfMissing()
            mutate(&p)
            profile = p
            return p
        }
    }

    @inline(__always)
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
