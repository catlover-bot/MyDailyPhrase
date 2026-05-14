import Foundation

public enum LinkedAuthProvider: String, Codable, CaseIterable, Sendable {
    case apple
    case google
    case x
}

public enum AuthAuditEventKind: String, Codable, CaseIterable, Sendable {
    case linked
    case unlinked
    case credentialVerified
    case credentialRevoked
    case credentialNotFound
    case verificationFailed
    case providerReplacementBlocked
}

public enum SecurityAuditCategory: String, Codable, CaseIterable, Sendable {
    case auth
    case gacha
    case community
}

public enum SecurityAuditSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
}

public enum SecurityAuditKind: String, Codable, CaseIterable, Sendable {
    case authLinked
    case authUnlinked
    case authCredentialVerified
    case authCredentialRevoked
    case authCredentialNotFound
    case authVerificationFailed
    case authProviderReplacementBlocked
    case authOnboardingCompleted

    case gachaDrawStarted
    case gachaDrawCompleted
    case gachaDrawFailed
    case gachaExchangeCompleted
    case gachaExchangeFailed
    case gachaDailyTicketGranted
    case gachaSeasonMilestoneClaimed

    case communityRoomJoined
    case communityRoomLeft
    case communityUserMuted
    case communityUserUnmuted
    case communityUserBlocked
    case communityUserUnblocked
    case communitySafetyReported
    case communityChallengeImported
    case communityReferralAccepted
    case communityReferralRewardClaimed
    case communityInviteShared
    case communityWeeklyRankingShared
    case communityWeeklyMissionClaimed
}

public struct SecurityAuditEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: SecurityAuditCategory
    public let kind: SecurityAuditKind
    public let severity: SecurityAuditSeverity
    public let title: String
    public let detail: String
    public let provider: String?
    public let actorHint: String?
    public let metadata: [String: String]
    public let occurredAt: Date

    public init(
        id: String = UUID().uuidString,
        category: SecurityAuditCategory,
        kind: SecurityAuditKind,
        severity: SecurityAuditSeverity = .info,
        title: String,
        detail: String,
        provider: String? = nil,
        actorHint: String? = nil,
        metadata: [String: String] = [:],
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.kind = kind
        self.severity = severity
        self.title = title
        self.detail = detail
        self.provider = provider
        self.actorHint = actorHint
        self.metadata = metadata
        self.occurredAt = occurredAt
    }
}

public struct AuthAuditEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: AuthAuditEventKind
    public let provider: String?
    public let authUserIdHint: String?
    public let message: String
    public let occurredAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: AuthAuditEventKind,
        provider: String? = nil,
        authUserIdHint: String? = nil,
        message: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.provider = provider
        self.authUserIdHint = authUserIdHint
        self.message = message
        self.occurredAt = occurredAt
    }
}

public struct UserProfile: Codable, Equatable, Sendable {
    public static let maxDisplayNameLength = 24
    public static let maxAuthAuditTrailCount = 50
    public static let maxSecurityAuditTrailCount = 180
    public static let maxOwnedDecorationCountPerId = 999
    public static let maxDecorationShards = 9_999_999
    public static let maxPityCount = 99_999
    public static let maxGachaTickets = 999_999

    public let userId: String
    public var displayName: String
    public var linkedAuthProvider: String?
    public var linkedAuthUserId: String?
    public var linkedAuthAt: Date?
    public var hasCompletedOnboarding: Bool
    public var onboardingCompletedAt: Date?
    public var onboardingVersion: Int
    public var authAuditTrail: [AuthAuditEvent]
    public var securityAuditTrail: [SecurityAuditEvent]

    // ===== Card Decoration / Gacha =====
    public var selectedDecorationId: String
    public var equippedDecorationSet: EquippedDecorationSet

    /// 互換用：古い実装との橋渡し（UIで “所持” 判定に使っている箇所があれば残す）
    public var ownedDecorationIds: [String]

    /// ✅ 新: 所持数（ここを正にすることで、アイテム管理が強くなる）
    public var ownedDecorationCounts: [String: Int]
    public var ownedDecorationRecords: [String: OwnedDecorationRecord]

    /// ✅ 新: 重複時に貯まる欠片（後で交換所に使う）
    public var decorationShards: Int

    /// ✅ 新: 天井カウント（Legendary でリセット）
    public var pityCount: Int

    public var gachaTickets: Int
    public var lastFreeTicketDateKey: String?

    public var linkedAuthProviderKind: LinkedAuthProvider? {
        get { linkedAuthProvider.flatMap(LinkedAuthProvider.init(rawValue:)) }
        set { linkedAuthProvider = newValue?.rawValue }
    }

    public init(
        userId: String,
        displayName: String,
        linkedAuthProvider: String? = nil,
        linkedAuthUserId: String? = nil,
        linkedAuthAt: Date? = nil,
        hasCompletedOnboarding: Bool = true,
        onboardingCompletedAt: Date? = nil,
        onboardingVersion: Int = 0,
        authAuditTrail: [AuthAuditEvent] = [],
        securityAuditTrail: [SecurityAuditEvent] = [],
        selectedDecorationId: String = CardDecorationCatalog.classicId,
        equippedDecorationSet: EquippedDecorationSet = EquippedDecorationSet(
            primaryDecorationId: CardDecorationCatalog.classicId
        ),
        ownedDecorationIds: [String] = [CardDecorationCatalog.classicId],
        ownedDecorationCounts: [String: Int] = [CardDecorationCatalog.classicId: 1],
        ownedDecorationRecords: [String: OwnedDecorationRecord] = [
            CardDecorationCatalog.classicId: OwnedDecorationRecord(
                acquisitionDate: .distantPast,
                source: .defaultItem,
                count: 1
            )
        ],
        decorationShards: Int = 0,
        pityCount: Int = 0,
        gachaTickets: Int = 0,
        lastFreeTicketDateKey: String? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.linkedAuthProvider = linkedAuthProvider
        self.linkedAuthUserId = linkedAuthUserId
        self.linkedAuthAt = linkedAuthAt
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingCompletedAt = onboardingCompletedAt
        self.onboardingVersion = onboardingVersion
        self.authAuditTrail = authAuditTrail
        self.securityAuditTrail = securityAuditTrail
        self.selectedDecorationId = selectedDecorationId
        self.equippedDecorationSet = equippedDecorationSet
        self.ownedDecorationIds = ownedDecorationIds
        self.ownedDecorationCounts = ownedDecorationCounts
        self.ownedDecorationRecords = ownedDecorationRecords
        self.decorationShards = decorationShards
        self.pityCount = pityCount
        self.gachaTickets = gachaTickets
        self.lastFreeTicketDateKey = lastFreeTicketDateKey

        self.normalize()
    }

    // 既存保存データ互換
    private enum CodingKeys: String, CodingKey {
        case userId, displayName
        case linkedAuthProvider
        case linkedAuthUserId
        case linkedAuthAt
        case hasCompletedOnboarding
        case onboardingCompletedAt
        case onboardingVersion
        case authAuditTrail
        case securityAuditTrail
        case selectedDecorationId
        case equippedDecorationSet
        case ownedDecorationIds
        case ownedDecorationCounts
        case ownedDecorationRecords
        case decorationShards
        case pityCount
        case gachaTickets
        case lastFreeTicketDateKey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.userId = try c.decode(String.self, forKey: .userId)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.linkedAuthProvider = try c.decodeIfPresent(String.self, forKey: .linkedAuthProvider)
        self.linkedAuthUserId = try c.decodeIfPresent(String.self, forKey: .linkedAuthUserId)
        self.linkedAuthAt = try c.decodeIfPresent(Date.self, forKey: .linkedAuthAt)
        self.hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
        self.onboardingCompletedAt = try c.decodeIfPresent(Date.self, forKey: .onboardingCompletedAt)
        self.onboardingVersion = try c.decodeIfPresent(Int.self, forKey: .onboardingVersion) ?? 0
        self.authAuditTrail = try c.decodeIfPresent([AuthAuditEvent].self, forKey: .authAuditTrail) ?? []
        self.securityAuditTrail = try c.decodeIfPresent([SecurityAuditEvent].self, forKey: .securityAuditTrail) ?? []
        if self.securityAuditTrail.isEmpty && !self.authAuditTrail.isEmpty {
            self.securityAuditTrail = self.authAuditTrail.map(SecurityAuditEvent.init(authAuditEvent:))
        }

        self.selectedDecorationId = try c.decodeIfPresent(String.self, forKey: .selectedDecorationId) ?? CardDecorationCatalog.classicId
        self.equippedDecorationSet = try c.decodeIfPresent(EquippedDecorationSet.self, forKey: .equippedDecorationSet)
            ?? EquippedDecorationSet(primaryDecorationId: self.selectedDecorationId)
        self.ownedDecorationIds = try c.decodeIfPresent([String].self, forKey: .ownedDecorationIds) ?? [CardDecorationCatalog.classicId]

        // ✅ 新フィールドが無い古いJSONは ownedDecorationIds から復元
        self.ownedDecorationCounts = try c.decodeIfPresent([String: Int].self, forKey: .ownedDecorationCounts)
            ?? Dictionary(uniqueKeysWithValues: self.ownedDecorationIds.map { ($0, 1) })
        self.ownedDecorationRecords = try c.decodeIfPresent([String: OwnedDecorationRecord].self, forKey: .ownedDecorationRecords)
            ?? Dictionary(
                uniqueKeysWithValues: self.ownedDecorationCounts.map { key, count in
                    (
                        key,
                        OwnedDecorationRecord(
                            acquisitionDate: .distantPast,
                            source: key == CardDecorationCatalog.classicId ? .defaultItem : .event,
                            count: max(0, count)
                        )
                    )
                }
            )

        self.decorationShards = try c.decodeIfPresent(Int.self, forKey: .decorationShards) ?? 0
        self.pityCount = try c.decodeIfPresent(Int.self, forKey: .pityCount) ?? 0
        self.gachaTickets = try c.decodeIfPresent(Int.self, forKey: .gachaTickets) ?? 0
        self.lastFreeTicketDateKey = try c.decodeIfPresent(String.self, forKey: .lastFreeTicketDateKey)

        self.normalize()
    }

    /// データ整合性を担保
    public mutating func normalize() {
        displayName = Self.normalizedDisplayName(displayName)
        linkedAuthProvider = Self.normalizedLinkedAuthProvider(linkedAuthProvider)
        linkedAuthUserId = Self.normalizedLinkedAuthUserId(linkedAuthUserId)
        if linkedAuthProvider == nil || linkedAuthUserId == nil {
            linkedAuthProvider = nil
            linkedAuthUserId = nil
            linkedAuthAt = nil
            hasCompletedOnboarding = true
            onboardingCompletedAt = nil
            onboardingVersion = 0
        }
        onboardingVersion = max(0, onboardingVersion)
        if !hasCompletedOnboarding {
            onboardingCompletedAt = nil
        }
        authAuditTrail = authAuditTrail.sorted { $0.occurredAt > $1.occurredAt }
        if authAuditTrail.count > Self.maxAuthAuditTrailCount {
            authAuditTrail = Array(authAuditTrail.prefix(Self.maxAuthAuditTrailCount))
        }
        if securityAuditTrail.isEmpty && !authAuditTrail.isEmpty {
            securityAuditTrail = authAuditTrail.map(SecurityAuditEvent.init(authAuditEvent:))
        }
        securityAuditTrail = securityAuditTrail.sorted { $0.occurredAt > $1.occurredAt }
        if securityAuditTrail.count > Self.maxSecurityAuditTrailCount {
            securityAuditTrail = Array(securityAuditTrail.prefix(Self.maxSecurityAuditTrailCount))
        }

        let validDecorationIDs = Set(CardDecorationCatalog.all.map(\.id))

        var mergedRecords: [String: OwnedDecorationRecord] = [:]
        mergedRecords.reserveCapacity(max(ownedDecorationCounts.count, ownedDecorationRecords.count))

        for (id, rawCount) in ownedDecorationCounts {
            guard validDecorationIDs.contains(id) else { continue }
            let normalizedCount = min(Self.maxOwnedDecorationCountPerId, max(0, rawCount))
            guard normalizedCount > 0 else { continue }
            let existing = ownedDecorationRecords[id]
            mergedRecords[id] = OwnedDecorationRecord(
                acquisitionDate: existing?.acquisitionDate ?? .distantPast,
                source: existing?.source ?? (id == CardDecorationCatalog.classicId ? .defaultItem : .event),
                count: normalizedCount
            )
        }

        for (id, record) in ownedDecorationRecords {
            guard validDecorationIDs.contains(id) else { continue }
            let normalizedCount = min(Self.maxOwnedDecorationCountPerId, max(0, record.count))
            guard normalizedCount > 0 else { continue }

            if let existing = mergedRecords[id] {
                mergedRecords[id] = OwnedDecorationRecord(
                    acquisitionDate: min(existing.acquisitionDate, record.acquisitionDate),
                    source: existing.source == .defaultItem ? record.source : existing.source,
                    count: max(existing.count, normalizedCount)
                )
            } else {
                mergedRecords[id] = OwnedDecorationRecord(
                    acquisitionDate: record.acquisitionDate,
                    source: record.source,
                    count: normalizedCount
                )
            }
        }

        if let classic = mergedRecords[CardDecorationCatalog.classicId] {
            mergedRecords[CardDecorationCatalog.classicId] = OwnedDecorationRecord(
                acquisitionDate: classic.acquisitionDate,
                source: .defaultItem,
                count: max(1, classic.count)
            )
        } else {
            mergedRecords[CardDecorationCatalog.classicId] = OwnedDecorationRecord(
                acquisitionDate: .distantPast,
                source: .defaultItem,
                count: 1
            )
        }

        ownedDecorationRecords = mergedRecords
        ownedDecorationCounts = mergedRecords.mapValues(\.count)

        ownedDecorationIds = ownedDecorationCounts
            .filter { $0.value > 0 }
            .map { $0.key }
            .sorted()

        if ownedDecorationIds.isEmpty {
            ownedDecorationIds = [CardDecorationCatalog.classicId]
        }

        // selected は所持に寄せる
        if !validDecorationIDs.contains(selectedDecorationId)
            || (ownedDecorationCounts[selectedDecorationId] ?? 0) <= 0 {
            selectedDecorationId = CardDecorationCatalog.classicId
        }

        equippedDecorationSet.primaryDecorationId = selectedDecorationId
        let selectedItem = CardDecorationCatalog.item(for: selectedDecorationId)

        func equippedIDIfEligible(_ type: DecorationItemType) -> String? {
            guard selectedItem?.itemType == type else { return nil }
            return selectedDecorationId
        }

        equippedDecorationSet.profileTitleDecorationId = equippedIDIfEligible(.profileTitle)
        equippedDecorationSet.shareTemplateDecorationId = equippedIDIfEligible(.shareTemplate)
        equippedDecorationSet.badgeDecorationId = equippedIDIfEligible(.badge)
        equippedDecorationSet.stickerDecorationId = equippedIDIfEligible(.sticker)
        equippedDecorationSet.auraDecorationId = equippedIDIfEligible(.auraStyle)

        decorationShards = min(Self.maxDecorationShards, max(0, decorationShards))
        pityCount = min(Self.maxPityCount, max(0, pityCount))
        gachaTickets = min(Self.maxGachaTickets, max(0, gachaTickets))

        if let key = lastFreeTicketDateKey?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty,
           Self.isValidDateKey(key) {
            lastFreeTicketDateKey = key
        } else {
            lastFreeTicketDateKey = nil
        }
    }

    private static func normalizedDisplayName(_ raw: String) -> String {
        let filteredScalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let noControl = String(String.UnicodeScalarView(filteredScalars))
        let collapsed = noControl
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let clipped = String(collapsed.prefix(maxDisplayNameLength))
        return clipped.isEmpty ? "Me" : clipped
    }

    private static func normalizedLinkedAuthProvider(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return LinkedAuthProvider(rawValue: trimmed)?.rawValue
    }

    private static func normalizedLinkedAuthUserId(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isValidDateKey(_ raw: String) -> Bool {
        guard raw.count == 8 else { return false }
        return raw.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains(_:))
    }
}

public extension SecurityAuditEvent {
    init(authAuditEvent event: AuthAuditEvent) {
        let kind: SecurityAuditKind
        let severity: SecurityAuditSeverity
        let title: String

        switch event.kind {
        case .linked:
            kind = .authLinked
            severity = .info
            title = "認証連携"
        case .unlinked:
            kind = .authUnlinked
            severity = .info
            title = "認証連携解除"
        case .credentialVerified:
            kind = .authCredentialVerified
            severity = .info
            title = "認証有効確認"
        case .credentialRevoked:
            kind = .authCredentialRevoked
            severity = .warning
            title = "認証失効検出"
        case .credentialNotFound:
            kind = .authCredentialNotFound
            severity = .warning
            title = "認証情報未検出"
        case .verificationFailed:
            kind = .authVerificationFailed
            severity = .error
            title = "認証検証エラー"
        case .providerReplacementBlocked:
            kind = .authProviderReplacementBlocked
            severity = .error
            title = "認証切替ブロック"
        }

        self.init(
            id: event.id,
            category: .auth,
            kind: kind,
            severity: severity,
            title: title,
            detail: event.message,
            provider: event.provider,
            actorHint: event.authUserIdHint,
            metadata: [:],
            occurredAt: event.occurredAt
        )
    }
}
