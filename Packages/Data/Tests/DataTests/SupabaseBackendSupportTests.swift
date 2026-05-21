import Foundation
import Testing
import Domain
@testable import Data

@Suite("Supabase backend support")
struct SupabaseBackendSupportTests {
    @Test("empty Supabase config is disabled and uses local fallback")
    func emptyConfigIsDisabled() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: false,
            projectURLString: nil,
            anonKey: nil
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .disabled)
        #expect(config.canUseSupabase == false)
        #expect(snapshot.activeMode == .localFallback)
        #expect(snapshot.publicFeedEnabled == false)
        #expect(snapshot.commentsEnabled == false)
        #expect(snapshot.rankingEnabled == false)
        #expect(snapshot.dmPolicy == "mutual_follow_only")
    }

    @Test("enabled Supabase without URL or key is safe missing configuration")
    func missingConfigIsSafe() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "",
            anonKey: " "
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .missingConfiguration)
        #expect(snapshot.activeMode == .localFallback)
        #expect(snapshot.anonKeyConfigured == false)
    }

    @Test("configured Supabase reports supabase active mode")
    func configuredSupabaseReportsActiveMode() {
        let config = SupabaseBackendConfiguration.make(
            isEnabledConfigured: true,
            projectURLString: "https://example.supabase.co",
            anonKey: "public-anon-key"
        )
        let snapshot = BackendDiagnosticsSnapshot(configuration: config)

        #expect(config.status == .configured)
        #expect(snapshot.activeMode == .supabase)
        #expect(snapshot.projectURLHost == "example.supabase.co")
        #expect(snapshot.anonKeyConfigured)
        #expect(snapshot.secretsInRepository == false)
    }

    @Test("local social repository excludes blocked recommendations and gates DM")
    func localSocialRepositorySafety() {
        let minato = SocialUserProfileSummary(
            id: "local.profile.minato",
            displayName: "ミナト",
            equippedThemeId: "classic",
            joinedCommunityCount: 1,
            supportsMutualDM: true
        )
        let sora = SocialUserProfileSummary(
            id: "local.profile.sora",
            displayName: "ソラ",
            equippedThemeId: "classic",
            joinedCommunityCount: 1,
            supportsMutualDM: true
        )
        let repository = LocalSocialConnectionRepository {
            [minato, sora]
        }
        var profile = UserProfile(
            userId: "me",
            displayName: "Me",
            followingUserIDs: ["local.profile.minato"],
            blockedUserIDs: ["local.profile.sora"]
        )
        profile.normalize()

        #expect(repository.listRecommendedProfiles(for: profile).isEmpty)
        #expect(repository.listFollowingProfiles(for: profile).map(\.id) == ["local.profile.minato"])
        #expect(repository.canStartDirectMessage(from: profile, to: minato))
        #expect(repository.canStartDirectMessage(from: profile, to: sora) == false)
    }
}
