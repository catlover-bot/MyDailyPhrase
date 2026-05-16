import Foundation
import Domain

public enum SocialSupport {
    private static let localFollowerPreviewIDs: Set<String> = [
        "local.profile.minato",
        "local.profile.sora"
    ]

    public static func demoProfiles() -> [SocialUserProfileSummary] {
        [
            SocialUserProfileSummary(
                id: "local.profile.minato",
                displayName: "ミナト",
                profileTitle: "RPGの旅人",
                equippedThemeId: "retro",
                joinedCommunityCount: 3,
                bio: "物語や仲間のいるゲームが好きです。",
                supportsMutualDM: true,
                isLocalOnly: true
            ),
            SocialUserProfileSummary(
                id: "local.profile.yuki",
                displayName: "ユキ",
                profileTitle: "積みゲー整理係",
                equippedThemeId: "paper",
                joinedCommunityCount: 2,
                bio: "今週ひらきたい一本をゆるく決めています。",
                supportsMutualDM: true,
                isLocalOnly: true
            ),
            SocialUserProfileSummary(
                id: "local.profile.sora",
                displayName: "ソラ",
                profileTitle: "FPSの振り返り役",
                equippedThemeId: "matrix",
                joinedCommunityCount: 1,
                bio: "対戦後の反省を短く残すのが好きです。",
                supportsMutualDM: true,
                isLocalOnly: true
            ),
            SocialUserProfileSummary(
                id: "local.profile.rin",
                displayName: "リン",
                profileTitle: "音ゲーのきらめき",
                equippedThemeId: "starlight",
                joinedCommunityCount: 2,
                bio: "好きな一曲や今日の譜面気分を残しています。",
                supportsMutualDM: false,
                isLocalOnly: true
            )
        ]
    }

    public static func applyRelationshipState(
        profiles: [SocialUserProfileSummary],
        followingUserIDs: Set<String>,
        blockedUserIDs: Set<String>,
        reportedUserIDs: Set<String>
    ) -> [SocialUserProfileSummary] {
        profiles
            .filter { !blockedUserIDs.contains($0.id) }
            .map { profile in
                SocialUserProfileSummary(
                    id: profile.id,
                    displayName: profile.displayName,
                    profileTitle: profile.profileTitle,
                    equippedThemeId: profile.equippedThemeId,
                    joinedCommunityCount: profile.joinedCommunityCount,
                    bio: profile.bio,
                    supportsMutualDM: profile.supportsMutualDM,
                    isLocalOnly: profile.isLocalOnly
                )
            }
            .sorted { lhs, rhs in
                let lhsFollowing = followingUserIDs.contains(lhs.id)
                let rhsFollowing = followingUserIDs.contains(rhs.id)
                if lhsFollowing != rhsFollowing {
                    return lhsFollowing && !rhsFollowing
                }
                let lhsReported = reportedUserIDs.contains(lhs.id)
                let rhsReported = reportedUserIDs.contains(rhs.id)
                if lhsReported != rhsReported {
                    return !lhsReported && rhsReported
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    public static func toggledFollowIDs(
        current: [String],
        targetUserID: String
    ) -> [String] {
        let target = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return current }

        var values = current.filter { $0 != target }
        if values.count == current.count {
            values.append(target)
        }
        return values
    }

    public static func blockedIDsAfterBlocking(
        current: [String],
        targetUserID: String
    ) -> [String] {
        let target = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return current }
        if current.contains(target) {
            return current.filter { $0 != target }
        }
        return current + [target]
    }

    public static func reportedIDsAfterReporting(
        current: [String],
        targetUserID: String
    ) -> [String] {
        let target = targetUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return current }
        if current.contains(target) {
            return current
        }
        return current + [target]
    }

    public static func followerPreviewProfiles(
        profiles: [SocialUserProfileSummary],
        blockedUserIDs: Set<String>
    ) -> [SocialUserProfileSummary] {
        profiles
            .filter { localFollowerPreviewIDs.contains($0.id) }
            .filter { !blockedUserIDs.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public static func mutualFollowUserIDs(
        followingUserIDs: Set<String>,
        followerUserIDs: Set<String>
    ) -> Set<String> {
        followingUserIDs.intersection(followerUserIDs)
    }

    public static func canUseDirectMessage(
        with profile: SocialUserProfileSummary,
        followingUserIDs: Set<String>,
        followerUserIDs: Set<String>,
        blockedUserIDs: Set<String>
    ) -> Bool {
        guard ReleaseFeatureAvailability.dmEnabled else { return false }
        guard !blockedUserIDs.contains(profile.id) else { return false }
        guard followingUserIDs.contains(profile.id) else { return false }
        guard followerUserIDs.contains(profile.id) else { return false }
        return profile.supportsMutualDM
    }

    public static func sanitizedMessageBody(_ raw: String) -> String {
        let collapsed = raw
            .split(whereSeparator: \.isNewline)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(240))
    }

    public static func conversationAfterSending(
        existing: DirectMessageConversation?,
        to profile: SocialUserProfileSummary,
        body: String,
        sentAt: Date
    ) -> DirectMessageConversation {
        var conversation = existing ?? DirectMessageConversation(
            participantUserID: profile.id,
            participantDisplayName: profile.displayName,
            participantProfileTitle: profile.profileTitle,
            participantDecorationID: profile.equippedThemeId,
            messages: []
        )
        let trimmed = sanitizedMessageBody(body)
        conversation.messages.append(
            DirectMessageMessage(
                sender: .me,
                body: trimmed,
                sentAt: sentAt
            )
        )
        conversation.updatedAt = sentAt
        conversation.normalize()
        return conversation
    }
}
