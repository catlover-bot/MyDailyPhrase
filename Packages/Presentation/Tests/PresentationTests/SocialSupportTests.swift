import Foundation
import Testing
import Domain
@testable import Presentation

@Suite("Social support")
struct SocialSupportTests {
    @Test("follow toggle adds and removes the same user")
    func togglesFollowState() {
        let once = SocialSupport.toggledFollowIDs(current: [], targetUserID: "local.profile.minato")
        let twice = SocialSupport.toggledFollowIDs(current: once, targetUserID: "local.profile.minato")

        #expect(once == ["local.profile.minato"])
        #expect(twice.isEmpty)
    }

    @Test("blocked profiles disappear from recommendations")
    func blockedProfilesAreFiltered() {
        let profiles = SocialSupport.applyRelationshipState(
            profiles: SocialSupport.demoProfiles(),
            followingUserIDs: [],
            blockedUserIDs: ["local.profile.rin"],
            reportedUserIDs: []
        )

        #expect(profiles.contains { $0.id == "local.profile.minato" })
        #expect(!profiles.contains { $0.id == "local.profile.rin" })
    }

    @Test("mutual follow style DM rule is enforced")
    func mutualFollowRule() {
        let profile = SocialSupport.demoProfiles().first { $0.id == "local.profile.minato" }!
        let disabled = SocialSupport.canUseDirectMessage(
            with: profile,
            followingUserIDs: [],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: []
        )
        let disabledWithoutFollower = SocialSupport.canUseDirectMessage(
            with: profile,
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: [],
            blockedUserIDs: []
        )
        let enabled = SocialSupport.canUseDirectMessage(
            with: profile,
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: []
        )

        #expect(disabled == false)
        #expect(disabledWithoutFollower == false)
        #expect(enabled == true)
    }

    @Test("DM unavailable reason explains non mutual state")
    func dmUnavailableReasonExplainsState() {
        let profile = SocialSupport.demoProfiles().first { $0.id == "local.profile.minato" }!

        let notFollowing = SocialSupport.directMessageUnavailableReason(
            with: profile,
            followingUserIDs: [],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: []
        )
        let notFollower = SocialSupport.directMessageUnavailableReason(
            with: profile,
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: [],
            blockedUserIDs: []
        )
        let blocked = SocialSupport.directMessageUnavailableReason(
            with: profile,
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: ["local.profile.minato"]
        )

        #expect(notFollowing?.contains("フォロー後") == true)
        #expect(notFollower?.contains("相手からも") == true)
        #expect(blocked?.contains("ブロック中") == true)
    }

    @Test("relationship labels expose follow mutual and blocked states")
    func relationshipLabels() {
        #expect(SocialSupport.relationshipLabel(
            profileID: "local.profile.minato",
            followingUserIDs: [],
            followerUserIDs: [],
            blockedUserIDs: []
        ) == "おすすめ")
        #expect(SocialSupport.relationshipLabel(
            profileID: "local.profile.minato",
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: [],
            blockedUserIDs: []
        ) == "フォロー中")
        #expect(SocialSupport.relationshipLabel(
            profileID: "local.profile.minato",
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: []
        ) == "相互フォロー")
        #expect(SocialSupport.relationshipLabel(
            profileID: "local.profile.minato",
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: ["local.profile.minato"]
        ) == "ブロック中")
    }

    @Test("blocked user cannot be DM target")
    func blockedUserCannotMessage() {
        let profile = SocialSupport.demoProfiles().first { $0.id == "local.profile.minato" }!
        let allowed = SocialSupport.canUseDirectMessage(
            with: profile,
            followingUserIDs: ["local.profile.minato"],
            followerUserIDs: ["local.profile.minato"],
            blockedUserIDs: ["local.profile.minato"]
        )

        #expect(allowed == false)
    }

    @Test("follower preview hides blocked users")
    func followerPreviewFiltersBlockedUsers() {
        let profiles = SocialSupport.followerPreviewProfiles(
            profiles: SocialSupport.demoProfiles(),
            blockedUserIDs: ["local.profile.sora"]
        )

        #expect(profiles.contains { $0.id == "local.profile.minato" })
        #expect(!profiles.contains { $0.id == "local.profile.sora" })
    }

    @Test("conversation send trims and stores local message")
    func conversationSendSanitizesMessage() {
        let profile = SocialSupport.demoProfiles().first { $0.id == "local.profile.minato" }!
        let conversation = SocialSupport.conversationAfterSending(
            existing: nil,
            to: profile,
            body: "  こんにちは\n",
            sentAt: Date(timeIntervalSince1970: 123)
        )

        #expect(conversation.participantUserID == "local.profile.minato")
        #expect(conversation.messages.count == 1)
        #expect(conversation.messages.first?.body == "こんにちは")
    }
}
