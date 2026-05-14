import Foundation
import Testing
import Domain
@testable import Presentation

@Suite("Community Lite support")
struct CommunityLiteSupportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    @Test("weekly challenge generation is deterministic by week")
    func weeklyChallengeDeterministic() {
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let secondDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 9))!

        let first = CommunityLiteSupport.challenge(for: firstDate, calendar: calendar)
        let second = CommunityLiteSupport.challenge(for: secondDate, calendar: calendar)

        #expect(first.weekKey == second.weekKey)
        #expect(first == second)
    }

    @Test("weekly challenge share text excludes private answer by default")
    func weeklyShareTextExcludesAnswerByDefault() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let challenge = CommunityLiteSupport.challenge(for: date, calendar: calendar)
        let answer = "今日は静かに深呼吸できた"

        let text = CommunityLiteSupport.weeklyChallengeShareText(
            challenge: challenge,
            displayName: "Me",
            profileTitle: "夜の記録者",
            reaction: .sparkles,
            answer: answer,
            includeAnswer: false
        )

        #expect(!text.contains(answer))
        #expect(text.contains("#ひとこと日記"))
    }

    @Test("release feature flags keep risky features disabled")
    func featureAvailability() {
        #expect(ReleaseFeatureAvailability.paidGachaEnabled == false)
        #expect(ReleaseFeatureAvailability.publicCommunityEnabled == false)
        #expect(ReleaseFeatureAvailability.communityLiteEnabled == true)
        #expect(ReleaseFeatureAvailability.gameCommunityEnabled == true)
        #expect(ReleaseFeatureAvailability.creatorPassEnabled == false)
        #expect(ReleaseFeatureAvailability.creatorCommunityCreationEnabled == false)
        #expect(ReleaseFeatureAvailability.nativeSharingEnabled == true)
    }

    @Test("non-paid user cannot create community")
    func nonPaidUserCannotCreateCommunity() {
        let state = CommunityLiteSupport.creatorEntitlementState(
            creatorPassEnabled: false,
            creatorCommunityCreationEnabled: false,
            creatorCommunityLocalDraftEnabled: true,
            storeKitEntitled: false,
            debugOverride: false
        )

        #expect(state.hasCreatorPass == false)
        #expect(state.canCreateCommunity == false)
        #expect(state.entitlementSource == .none)
    }

    @Test("creator-entitled user can create local community template")
    func creatorEntitledUserCanCreateCommunity() {
        let state = CommunityLiteSupport.creatorEntitlementState(
            creatorPassEnabled: false,
            creatorCommunityCreationEnabled: false,
            creatorCommunityLocalDraftEnabled: true,
            storeKitEntitled: false,
            debugOverride: true
        )

        #expect(state.hasCreatorPass == true)
        #expect(state.canCreateCommunity == true)
        #expect(state.entitlementSource == .debugOverride)
    }

    @Test("default community share payload does not include answer")
    func defaultCommunityShareExcludesAnswer() {
        let community = CommunityLiteSupport.officialPresetCommunities()[0]
        let prompt = CommunityPrompt(
            id: "p1",
            communityId: community.id,
            text: "最近いちばん時間を忘れたゲームは？",
            category: .games,
            tags: ["games"],
            dateKey: "20260514",
            shareSafe: true,
            createdBy: .system,
            answerStyle: .onePhrase
        )
        let answer = "最近はRPGに夢中"

        let text = CommunityLiteSupport.communityPromptShareText(
            community: community,
            prompt: prompt,
            answer: answer,
            includeAnswer: false,
            reaction: .sparkles
        )

        #expect(!text.contains(answer))
        #expect(text.contains("#ゲーム日記"))
    }

    @Test("explicit community answer share payload includes answer")
    func explicitCommunityShareIncludesAnswer() {
        let community = CommunityLiteSupport.officialPresetCommunities()[0]
        let prompt = CommunityPrompt(
            id: "p1",
            communityId: community.id,
            text: "最近いちばん時間を忘れたゲームは？",
            category: .games,
            tags: ["games"],
            dateKey: "20260514",
            shareSafe: true,
            createdBy: .system,
            answerStyle: .onePhrase
        )
        let answer = "最近はRPGに夢中"

        let text = CommunityLiteSupport.communityPromptShareText(
            community: community,
            prompt: prompt,
            answer: answer,
            includeAnswer: true,
            reaction: .sparkles
        )

        #expect(text.contains(answer))
    }

    @Test("joined community share text contains no debug identifiers")
    func joinedCommunityShareTextAvoidsDebugIds() {
        let community = CommunityLiteSupport.officialPresetCommunities()[0]
        let text = CommunityLiteSupport.joinedCommunityShareText(community: community)

        #expect(!text.contains(community.id))
        #expect(text.contains(community.name))
    }
}
