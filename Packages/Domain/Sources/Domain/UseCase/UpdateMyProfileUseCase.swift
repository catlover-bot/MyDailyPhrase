import Foundation
import Domain

public struct UpdateMyProfileUseCase: Sendable {
    private let repo: UserProfileRepository
    private let makeId: @Sendable () -> String

    public init(
        repo: UserProfileRepository,
        makeId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.repo = repo
        self.makeId = makeId
    }

    @discardableResult
    public func callAsFunction(
        displayName: String? = nil,
        selectedDecorationId: String? = nil,

        // 互換（古いUIやデータのため）
        ownedDecorationIds: [String]? = nil,

        // ✅ 新：管理の本体
        ownedDecorationCounts: [String: Int]? = nil,
        decorationShards: Int? = nil,
        pityCount: Int? = nil,

        gachaTickets: Int? = nil,
        lastFreeTicketDateKey: String? = nil,

        // ✅ 追加：差分加算（IAP などで便利）
        addGachaTickets: Int? = nil,
        addDecorationShards: Int? = nil
    ) -> UserProfile {
        repo.mutateMyProfile(
            { p in
                if let displayName { p.displayName = displayName }
                if let selectedDecorationId { p.selectedDecorationId = selectedDecorationId }

                // counts を優先（置換）
                if let ownedDecorationCounts {
                    // 負値は0に寄せる
                    var cleaned: [String: Int] = [:]
                    cleaned.reserveCapacity(ownedDecorationCounts.count)
                    for (k, v) in ownedDecorationCounts {
                        cleaned[k] = max(0, v)
                    }
                    p.ownedDecorationCounts = cleaned
                }

                // ownedDecorationIds が渡ってきたら「所持保証」として counts に反映（破壊的に消さない）
                if let ownedDecorationIds {
                    for id in ownedDecorationIds {
                        let cur = p.ownedDecorationCounts[id] ?? 0
                        p.ownedDecorationCounts[id] = max(1, cur)
                    }
                }

                if let decorationShards { p.decorationShards = decorationShards }
                if let pityCount { p.pityCount = pityCount }
                if let gachaTickets { p.gachaTickets = gachaTickets }
                if let lastFreeTicketDateKey { p.lastFreeTicketDateKey = lastFreeTicketDateKey }

                if let addGachaTickets {
                    p.gachaTickets = max(0, p.gachaTickets + addGachaTickets)
                }
                if let addDecorationShards {
                    p.decorationShards = max(0, p.decorationShards + addDecorationShards)
                }

                // 整合性補正（classic所持/selected補正/負値補正/ids同期）
                p.normalize()
            },
            makeIfMissing: {
                UserProfile(userId: makeId(), displayName: "Me")
            }
        )
    }
}
