import Foundation

enum ReferralProgram {
    static let scheme = "mydailyphrase"
    static let hostInvite = "invite"
    static let hostInviteAcknowledgement = "invite_ack"

    static let inviteeRewardTickets = 3
    static let inviterRewardTickets = 3

    static let pendingInviterIDKey = "MyDailyPhrase.referral.pending.inviterId.v1"
    static let pendingInviterNameKey = "MyDailyPhrase.referral.pending.inviterName.v1"
    static let pendingCodeKey = "MyDailyPhrase.referral.pending.code.v1"
    static let pendingReceivedAtKey = "MyDailyPhrase.referral.pending.receivedAt.v1"
    static let pendingAcknowledgementURLKey = "MyDailyPhrase.referral.pending.ackURL.v1"

    static let acceptedInviterIDsKey = "MyDailyPhrase.referral.acceptedInviterIds.v1"
    static let claimedInviteeIDsKey = "MyDailyPhrase.referral.claimedInviteeIds.v1"

    struct InvitePayload: Equatable, Sendable {
        let inviterId: String
        let inviterName: String
        let code: String
    }

    struct AcknowledgementPayload: Equatable, Sendable {
        let inviterId: String
        let inviteeId: String
        let inviteeName: String
        let code: String
    }

    static func referralCode(for userId: String) -> String {
        let compact = userId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard !compact.isEmpty else { return "MDP-GUEST" }
        return "MDP-\(compact.suffix(8))"
    }

    static func inviteURL(inviterId: String, inviterName: String, code: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostInvite
        components.queryItems = [
            URLQueryItem(name: "inviterId", value: inviterId),
            URLQueryItem(name: "inviterName", value: inviterName),
            URLQueryItem(name: "code", value: code)
        ]
        return components.url
    }

    static func acknowledgementURL(
        inviterId: String,
        inviteeId: String,
        inviteeName: String,
        code: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostInviteAcknowledgement
        components.queryItems = [
            URLQueryItem(name: "inviterId", value: inviterId),
            URLQueryItem(name: "inviteeId", value: inviteeId),
            URLQueryItem(name: "inviteeName", value: inviteeName),
            URLQueryItem(name: "code", value: code)
        ]
        return components.url
    }

    static func parseInvite(url: URL) -> InvitePayload? {
        guard url.scheme == scheme, url.host == hostInvite else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let inviterId = queryValue("inviterId", from: components)
        let inviterName = queryValue("inviterName", from: components)
        let code = queryValue("code", from: components)
        guard !inviterId.isEmpty, !inviterName.isEmpty, !code.isEmpty else { return nil }
        return InvitePayload(inviterId: inviterId, inviterName: inviterName, code: code)
    }

    static func parseAcknowledgement(url: URL) -> AcknowledgementPayload? {
        guard url.scheme == scheme, url.host == hostInviteAcknowledgement else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let inviterId = queryValue("inviterId", from: components)
        let inviteeId = queryValue("inviteeId", from: components)
        let inviteeName = queryValue("inviteeName", from: components)
        let code = queryValue("code", from: components)
        guard !inviterId.isEmpty, !inviteeId.isEmpty, !inviteeName.isEmpty, !code.isEmpty else { return nil }
        return AcknowledgementPayload(inviterId: inviterId, inviteeId: inviteeId, inviteeName: inviteeName, code: code)
    }

    private static func queryValue(_ name: String, from components: URLComponents) -> String {
        components.queryItems?
            .first(where: { $0.name == name })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
