import Foundation
import Testing
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
        #expect(ReleaseFeatureAvailability.nativeSharingEnabled == true)
    }
}
