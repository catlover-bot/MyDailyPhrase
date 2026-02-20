import Foundation
import Combine
import AuthenticationServices
import UserNotifications
import Domain

@MainActor
final class ProfileViewModel: ObservableObject {
    private static let defaultDisplayName = "Me"

    enum SecurityLogCategoryFilter: String, CaseIterable, Identifiable {
        case all
        case auth
        case gacha
        case community

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "全体"
            case .auth: return "認証"
            case .gacha: return "ガチャ"
            case .community: return "コミュニティ"
            }
        }
    }

    enum SecurityLogFilter: String, CaseIterable, Identifiable {
        case all
        case linked
        case unlinked
        case revoked
        case error

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "すべて"
            case .linked: return "連携"
            case .unlinked: return "解除"
            case .revoked: return "失効"
            case .error: return "エラー"
            }
        }
    }

    enum ReleaseReadinessStatus: Equatable {
        case ready
        case warning
        case missing

        var title: String {
            switch self {
            case .ready: return "Ready"
            case .warning: return "Warning"
            case .missing: return "Missing"
            }
        }

        var icon: String {
            switch self {
            case .ready: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .missing: return "xmark.octagon.fill"
            }
        }
    }

    struct ReleaseReadinessCheck: Identifiable {
        let id: String
        let title: String
        let detail: String
        let status: ReleaseReadinessStatus
        let required: Bool
    }

    enum SecurityLogDeletionPolicy: String, CaseIterable, Identifiable {
        case filteredOnly
        case olderThanRetention
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .filteredOnly: return "表示中のみ削除"
            case .olderThanRetention: return "保持期間超過を削除"
            case .all: return "全削除"
            }
        }
    }

    @Published private(set) var userId: String = ""
    @Published var displayName: String = ""
    @Published private(set) var linkedAuthProvider: String? = nil
    @Published private(set) var linkedAuthUserIdHint: String = "-"
    @Published private(set) var hasCompletedOnboarding: Bool = true
    @Published private(set) var isCheckingLinkedAuthState: Bool = false
    @Published private(set) var authAuditTrail: [AuthAuditEvent] = []
    @Published private(set) var securityAuditTrail: [SecurityAuditEvent] = []
    @Published var securityLogCategoryFilter: SecurityLogCategoryFilter = .all
    @Published var securityLogFilter: SecurityLogFilter = .all
    @Published var securityLogDeletionPolicy: SecurityLogDeletionPolicy = .filteredOnly
    @Published var securityLogRetentionDays: Int = 90
    @Published var externalAuthVerificationToken: String = ""
    @Published private(set) var isLinkingExternalAuth: Bool = false

    // ===== Decoration / Gacha =====
    @Published private(set) var ownedDecorationIds: [String] = []
    @Published var selectedDecorationId: String = "classic"
    @Published private(set) var gachaTickets: Int = 0

    // ===== Referral =====
    @Published private(set) var referralCode: String = "MDP-GUEST"
    @Published private(set) var referralInviteURL: URL? = nil
    @Published private(set) var pendingReferralInvite: ReferralProgram.InvitePayload? = nil
    @Published private(set) var referralAcknowledgementURL: URL? = nil
    @Published private(set) var referralAcceptedCount: Int = 0
    @Published private(set) var referralClaimedCount: Int = 0

    // ===== Push Notification =====
    @Published var pushNotificationsEnabled: Bool = false
    @Published var pushPromptUpdateEnabled: Bool = true
    @Published var pushMissionEnabled: Bool = true
    @Published var pushStreakReminderEnabled: Bool = true
    @Published var pushWeeklyTrendEnabled: Bool = true
    @Published private(set) var pushAuthorizationStatusText: String = "未確認"
    @Published private(set) var notificationABDashboardVersion: Int = 0

    @Published var lastMessage: String? = nil
    @Published private(set) var displayNameSavedValue: String = defaultDisplayName

    struct OnboardingNotificationPlan: Equatable, Sendable {
        var isEnabled: Bool
        var promptUpdateEnabled: Bool
        var missionEnabled: Bool
        var streakReminderEnabled: Bool
        var weeklyTrendEnabled: Bool
        var requestPermission: Bool

        static let recommended = OnboardingNotificationPlan(
            isEnabled: true,
            promptUpdateEnabled: true,
            missionEnabled: true,
            streakReminderEnabled: true,
            weeklyTrendEnabled: true,
            requestPermission: true
        )
    }

    struct NotificationABVariantRow: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let sent: Int
        let openRateText: String
        let returnRateText: String
        let weightedScoreText: String
    }

    struct NotificationABWeekdayRow: Identifiable, Equatable, Sendable {
        let id: String
        let weekdayLabel: String
        let winnerLabel: String
        let confidenceLabel: String
        let totalSent: Int
        let variants: [NotificationABVariantRow]
    }

    struct NotificationTimingSlotRow: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let sent: Int
        let openRateText: String
        let returnRateText: String
        let weightedScoreText: String
    }

    struct NotificationTimingWeekdayRow: Identifiable, Equatable, Sendable {
        let id: String
        let weekdayLabel: String
        let optimizationLabel: String
        let confidenceLabel: String
        let totalSent: Int
        let slots: [NotificationTimingSlotRow]
    }

    struct NotificationABDashboardRow: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let optimizationLabel: String
        let confidenceLabel: String
        let totalSent: Int
        let variants: [NotificationABVariantRow]
        let weekdayRows: [NotificationABWeekdayRow]
        let timingSlots: [NotificationTimingSlotRow]
        let timingWeekdayRows: [NotificationTimingWeekdayRow]
    }

    private let get: GetMyProfileUseCase
    private let update: UpdateMyProfileUseCase
    private let authTokenVerifier: ExternalAuthTokenVerifier
    private let termsOfServiceURLValue: URL?
    private let privacyPolicyURLValue: URL?
    private let onboardingSchemaVersion: Int = 1
    private let securityLogRetentionMaxDays: Int
    private let isServerAuthVerificationConfigured: Bool
    private let serverAuthEndpointHost: String?
    private let isDevelopmentVerifierEnabled: Bool
    private let externalAuthTokenBroker: ExternalAuthTokenBroker?
    private let oauthConfiguredProviders: Set<ExternalAuthProvider>
    private let oauthCallbackScheme: String?
    private let isOAuthCallbackSchemeRegistered: Bool
    private let allowsManualExternalAuthTokenInput: Bool
    private let isLoginBypassEnabled: Bool
    private let appDefaults: UserDefaults
    private let userNotificationCenter: UNUserNotificationCenter
    private let notificationCenter: NotificationCenter
    private let profileRecoveryMarkerKey = "MyDailyPhrase.profile.recoveredAt.v1"
    private let profileCorruptStoreKey = "MyDailyPhrase.profile.corrupt.v1"
    private var linkedAuthUserIdRaw: String? = nil
    private var cancellables: Set<AnyCancellable> = []
    private var isApplyingNotificationPreferences = false

    init(
        get: GetMyProfileUseCase,
        update: UpdateMyProfileUseCase,
        authTokenVerifier: ExternalAuthTokenVerifier,
        termsOfServiceURL: URL? = nil,
        privacyPolicyURL: URL? = nil,
        defaultSecurityLogRetentionDays: Int = 90,
        maxSecurityLogRetentionDays: Int = 365,
        isServerAuthVerificationConfigured: Bool = false,
        serverAuthEndpointHost: String? = nil,
        isDevelopmentVerifierEnabled: Bool = false,
        externalAuthTokenBroker: ExternalAuthTokenBroker? = nil,
        oauthConfiguredProviders: Set<ExternalAuthProvider> = [],
        oauthCallbackScheme: String? = nil,
        isOAuthCallbackSchemeRegistered: Bool = false,
        allowsManualExternalAuthTokenInput: Bool = true,
        isLoginBypassEnabled: Bool = false,
        appDefaults: UserDefaults = .standard,
        userNotificationCenter: UNUserNotificationCenter = .current(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.get = get
        self.update = update
        self.authTokenVerifier = authTokenVerifier
        self.termsOfServiceURLValue = termsOfServiceURL
        self.privacyPolicyURLValue = privacyPolicyURL
        let normalizedMax = max(7, maxSecurityLogRetentionDays)
        self.securityLogRetentionMaxDays = normalizedMax
        self.securityLogRetentionDays = min(max(7, defaultSecurityLogRetentionDays), normalizedMax)
        self.isServerAuthVerificationConfigured = isServerAuthVerificationConfigured
        self.serverAuthEndpointHost = serverAuthEndpointHost
        self.isDevelopmentVerifierEnabled = isDevelopmentVerifierEnabled
        self.externalAuthTokenBroker = externalAuthTokenBroker
        self.oauthConfiguredProviders = oauthConfiguredProviders
        self.oauthCallbackScheme = oauthCallbackScheme
        self.isOAuthCallbackSchemeRegistered = isOAuthCallbackSchemeRegistered
        self.allowsManualExternalAuthTokenInput = allowsManualExternalAuthTokenInput
        self.isLoginBypassEnabled = isLoginBypassEnabled
        self.appDefaults = appDefaults
        self.userNotificationCenter = userNotificationCenter
        self.notificationCenter = notificationCenter

        configureNotificationPreferenceBindings()
        configureExternalObservers()
        loadNotificationPreferencesFromDefaults()
        refreshPushNotificationAuthorizationStatus()
    }

    // MARK: - Catalog (App側で定義。ID文字列はShareCard側でも使う)

    struct Decoration: Identifiable, Equatable {
        let id: String
        let name: String
        let rarity: Rarity
        let weight: Int
    }

    enum Rarity: String, CaseIterable {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"
    }

    private var catalog: [Decoration] {
        CardDecorationCatalog.all.map { item in
            Decoration(
                id: item.id,
                name: item.name,
                rarity: mapRarity(item.rarity),
                weight: item.weight
            )
        }
    }

    var ownedDecorations: [Decoration] {
        let map = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        // classic を必ず表示
        let ids = Array(Set(ownedDecorationIds + ["classic"]))
        return ids.compactMap { map[$0] }.sorted { a, b in
            // rarity順 + 名前順（任意）
            let ra = rank(a.rarity), rb = rank(b.rarity)
            if ra != rb { return ra < rb }
            return a.name < b.name
        }
    }

    func ratesTextByRarity() -> [String] {
        let pool = catalog.filter { $0.weight > 0 }
        let sum = pool.reduce(0) { $0 + $1.weight }
        guard sum > 0 else { return [] }

        var buckets: [Rarity: Int] = [:]
        for d in pool { buckets[d.rarity, default: 0] += d.weight }

        return Rarity.allCases.compactMap { r in
            guard let w = buckets[r], w > 0 else { return nil }
            let pct = Double(w) / Double(sum) * 100.0
            return "\(r.rawValue): \(String(format: "%.1f", pct))%"
        }
    }

    private func rank(_ r: Rarity) -> Int {
        switch r {
        case .legendary: return 0
        case .epic: return 1
        case .rare: return 2
        case .common: return 3
        }
    }

    private func mapRarity(_ rarity: CardDecorationRarity) -> Rarity {
        switch rarity {
        case .common:
            return .common
        case .rare:
            return .rare
        case .epic:
            return .epic
        case .legendary:
            return .legendary
        }
    }

    // MARK: - Load / Save

    func load() {
        applyProfile(get())
        reloadReferralState()
        loadNotificationPreferencesFromDefaults()
        refreshPushNotificationAuthorizationStatus()
    }

    func save() {
        let normalized = normalizedDisplayName(displayName)
        let shouldExplainNormalization = normalized != displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = update(displayName: normalized)
        applyProfile(p)

        if shouldExplainNormalization {
            lastMessage = "表示名を整形して保存しました: \(p.displayName)"
        } else {
            lastMessage = "表示名を保存しました"
        }
    }

    var linkedAuthProviderName: String {
        switch linkedAuthProvider.flatMap(LinkedAuthProvider.init(rawValue:)) {
        case .apple:
            return "Sign in with Apple"
        case .google:
            return "Google"
        case .x:
            return "X"
        case .none:
            return "未連携"
        }
    }

    var linkedAuthStatusText: String {
        if linkedAuthProvider == nil {
            return "現在はローカルプロファイルで利用中です"
        }
        return "\(linkedAuthProviderName) 連携済み（\(linkedAuthUserIdHint)）"
    }

    var hasLinkedAuth: Bool {
        linkedAuthProvider != nil
    }

    var requiresInitialOnboarding: Bool {
        hasLinkedAuth && !hasCompletedOnboarding
    }

    var canInputExternalAuthTokenManually: Bool {
        allowsManualExternalAuthTokenInput
    }

    var isGoogleLoginAvailable: Bool {
        oauthConfiguredProviders.contains(.google)
    }

    var isXLoginAvailable: Bool {
        oauthConfiguredProviders.contains(.x)
    }

    var canLinkGoogleAccount: Bool {
        canLinkExternalAccount(provider: .google)
    }

    var canLinkXAccount: Bool {
        canLinkExternalAccount(provider: .x)
    }

    var externalAuthInputGuideText: String {
        if allowsManualExternalAuthTokenInput {
            return "DEBUGビルドでは検証トークンの手入力が使えます。Releaseでは無効化されます。"
        }
        if !isGoogleLoginAvailable && !isXLoginAvailable {
            return "現在の本番設定では外部ログインは Sign in with Apple のみ対応しています。"
        }
        if oauthCallbackScheme == nil {
            return "OAuth callback scheme が未設定です（AUTH_OAUTH_CALLBACK_SCHEME）"
        }
        if !isOAuthCallbackSchemeRegistered {
            return "OAuth callback scheme がURLスキームに未登録です（Info.plist: CFBundleURLTypes）"
        }
        return "Google/XログインはバックエンドOAuth開始URLとコールバック設定で動作します。"
    }

    var canVerifyLinkedAuthState: Bool {
        linkedAuthProvider == LinkedAuthProvider.apple.rawValue && (linkedAuthUserIdRaw?.isEmpty == false)
    }

    var filteredSecurityAuditTrail: [SecurityAuditEvent] {
        securityAuditTrail
            .filter(matchesSecurityCategoryFilter)
            .filter(matchesSecurityFilter)
    }

    var termsOfServiceURL: URL? {
        termsOfServiceURLValue
    }

    var privacyPolicyURL: URL? {
        privacyPolicyURLValue
    }

    var securityLogRetentionRange: ClosedRange<Int> {
        7...securityLogRetentionMaxDays
    }

    var securityLogCategoryFilterHint: String {
        switch securityLogCategoryFilter {
        case .all:
            return "認証・ガチャ・コミュニティの全監査イベント"
        case .auth:
            return "外部ログインと資格状態の監査イベント"
        case .gacha:
            return "抽選・交換・無料券処理の監査イベント"
        case .community:
            return "ルーム参加や安全対応の監査イベント"
        }
    }

    func linkAppleAccount(appleUserID: String, fullName: PersonNameComponents?) {
        if let current = linkedAuthProvider, current != LinkedAuthProvider.apple.rawValue {
            appendAuthAudit(
                kind: .providerReplacementBlocked,
                provider: current,
                authUserId: linkedAuthUserIdRaw,
                message: "他プロバイダ連携中のためApple連携をブロック"
            )
            lastMessage = "\(linkedAuthProviderName) 連携を解除してからApple連携に切り替えてください"
            return
        }

        let normalizedAuthUserID = appleUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAuthUserID.isEmpty else {
            lastMessage = "Appleアカウント情報の取得に失敗しました"
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let suggestedName = fullName.map { formatter.string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let shouldAutoFillName = displayNameSavedValue == Self.defaultDisplayName
        let displayNameToSave: String? = (shouldAutoFillName && !suggestedName.isEmpty) ? suggestedName : nil

        let p = update(
            displayName: displayNameToSave,
            linkedAuthProvider: "apple",
            linkedAuthUserId: normalizedAuthUserID,
            linkedAuthAt: Date(),
            hasCompletedOnboarding: false,
            onboardingVersion: 0,
            appendAuthAuditEvent: makeAuthAudit(
                kind: .linked,
                provider: LinkedAuthProvider.apple.rawValue,
                authUserId: normalizedAuthUserID,
                message: "Sign in with Apple を連携"
            )
        )
        applyProfile(p)
        lastMessage = "Sign in with Apple を連携しました"
    }

    func linkGoogleAccountUsingServerToken() async {
        await linkExternalAccountUsingServerToken(provider: .google)
    }

    func linkXAccountUsingServerToken() async {
        await linkExternalAccountUsingServerToken(provider: .x)
    }

    func verifyLinkedAuthState() {
        guard !isCheckingLinkedAuthState else { return }
        guard hasLinkedAuth else {
            lastMessage = "外部ログイン連携は未設定です"
            return
        }
        guard canVerifyLinkedAuthState, let authUserId = linkedAuthUserIdRaw else {
            lastMessage = "\(linkedAuthProviderName) の資格状態チェックは未対応です"
            return
        }

        isCheckingLinkedAuthState = true
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: authUserId) { [weak self] state, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCheckingLinkedAuthState = false

                if let error {
                    self.appendAuthAudit(
                        kind: .verificationFailed,
                        provider: self.linkedAuthProvider,
                        authUserId: self.linkedAuthUserIdRaw,
                        message: "連携状態確認エラー: \(error.localizedDescription)"
                    )
                    self.lastMessage = "連携状態の確認に失敗しました: \(error.localizedDescription)"
                    return
                }

                switch state {
                case .authorized:
                    self.appendAuthAudit(
                        kind: .credentialVerified,
                        provider: self.linkedAuthProvider,
                        authUserId: self.linkedAuthUserIdRaw,
                        message: "Apple連携状態を確認（有効）"
                    )
                    self.lastMessage = "Apple連携は有効です"
                case .revoked:
                    let p = self.update(
                        clearLinkedAuth: true,
                        appendAuthAuditEvent: self.makeAuthAudit(
                            kind: .credentialRevoked,
                            provider: LinkedAuthProvider.apple.rawValue,
                            authUserId: authUserId,
                            message: "Apple連携が失効状態だったため解除"
                        )
                    )
                    self.applyProfile(p)
                    self.lastMessage = "Apple連携が無効化されていたため解除しました"
                case .notFound:
                    let p = self.update(
                        clearLinkedAuth: true,
                        appendAuthAuditEvent: self.makeAuthAudit(
                            kind: .credentialNotFound,
                            provider: LinkedAuthProvider.apple.rawValue,
                            authUserId: authUserId,
                            message: "Apple連携情報が見つからないため解除"
                        )
                    )
                    self.applyProfile(p)
                    self.lastMessage = "Apple連携が無効化されていたため解除しました"
                case .transferred:
                    let p = self.update(
                        clearLinkedAuth: true,
                        appendAuthAuditEvent: self.makeAuthAudit(
                            kind: .credentialRevoked,
                            provider: LinkedAuthProvider.apple.rawValue,
                            authUserId: authUserId,
                            message: "Apple連携が移行状態だったため解除"
                        )
                    )
                    self.applyProfile(p)
                    self.lastMessage = "Apple連携が移行状態のため解除しました"
                @unknown default:
                    self.lastMessage = "Apple連携状態を判定できませんでした"
                }
            }
        }
    }

    func clearLinkedAccount() {
        let p = update(
            clearLinkedAuth: true,
            appendAuthAuditEvent: makeAuthAudit(
                kind: .unlinked,
                provider: linkedAuthProvider,
                authUserId: linkedAuthUserIdRaw,
                message: "外部ログイン連携を解除"
            )
        )
        applyProfile(p)
        lastMessage = "外部ログイン連携を解除しました"
    }

    func completeInitialOnboarding(preferredDisplayName: String, notificationPlan: OnboardingNotificationPlan) {
        let normalized = normalizedDisplayName(preferredDisplayName)
        let actorHint = userId.isEmpty ? nil : String(userId.suffix(8))
        let updated = update(
            displayName: normalized,
            hasCompletedOnboarding: true,
            onboardingCompletedAt: Date(),
            onboardingVersion: onboardingSchemaVersion,
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .auth,
                kind: .authOnboardingCompleted,
                title: "初回オンボーディング完了",
                detail: "provider=\(linkedAuthProvider ?? "-")",
                provider: linkedAuthProvider,
                actorHint: actorHint
            )
        )
        applyProfile(updated)
        applyOnboardingNotificationPlan(notificationPlan)
        notificationCenter.post(name: .profileDidUpdate, object: nil)
        lastMessage = "初期設定を保存しました"
    }

    func completeInitialOnboarding(preferredDisplayName: String, requestPushPermission: Bool) {
        var plan = OnboardingNotificationPlan.recommended
        plan.requestPermission = requestPushPermission
        completeInitialOnboarding(preferredDisplayName: preferredDisplayName, notificationPlan: plan)
    }

    func applySecurityLogDeletionPolicy() {
        let current = securityAuditTrail
        guard !current.isEmpty else {
            lastMessage = "削除対象のログがありません"
            return
        }

        let next: [SecurityAuditEvent]
        switch securityLogDeletionPolicy {
        case .filteredOnly:
            let idsToDelete = Set(filteredSecurityAuditTrail.map(\.id))
            next = current.filter { !idsToDelete.contains($0.id) }
        case .olderThanRetention:
            let days = min(securityLogRetentionMaxDays, max(7, securityLogRetentionDays))
            securityLogRetentionDays = days
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400.0)
            next = current.filter { $0.occurredAt >= cutoff }
        case .all:
            next = []
        }

        let removedCount = max(0, current.count - next.count)
        guard removedCount > 0 else {
            lastMessage = "削除対象のログがありません"
            return
        }

        let p = update(securityAuditTrail: next)
        applyProfile(p)
        lastMessage = "セキュリティログを\(removedCount)件削除しました"
    }

    func acceptPendingReferralReward() {
        guard let pending = pendingReferralInvite else {
            lastMessage = "受け取り可能な招待がありません"
            return
        }

        let me = get()
        if pending.inviterId == me.userId {
            clearPendingReferralInviteFromDefaults()
            pendingReferralInvite = nil
            lastMessage = "自分の招待リンクは受け取れません"
            return
        }

        var acceptedInviterIDs = loadStringSet(forKey: ReferralProgram.acceptedInviterIDsKey)
        if acceptedInviterIDs.contains(pending.inviterId) {
            clearPendingReferralInviteFromDefaults()
            pendingReferralInvite = nil
            lastMessage = "この招待はすでに受け取り済みです"
            return
        }

        acceptedInviterIDs.insert(pending.inviterId)
        saveStringSet(acceptedInviterIDs, forKey: ReferralProgram.acceptedInviterIDsKey)

        let actorHint = me.userId.isEmpty ? nil : String(me.userId.suffix(8))
        let updated = update(
            appendSecurityAuditEvent: SecurityAuditEvent(
                category: .community,
                kind: .communityReferralAccepted,
                title: "招待報酬（被招待者）",
                detail: "inviter=\(pending.inviterName) code=\(pending.code)",
                actorHint: actorHint,
                metadata: [
                    "inviterId": pending.inviterId
                ]
            ),
            addGachaTickets: ReferralProgram.inviteeRewardTickets
        )
        applyProfile(updated)

        referralAcknowledgementURL = ReferralProgram.acknowledgementURL(
            inviterId: pending.inviterId,
            inviteeId: updated.userId,
            inviteeName: updated.displayName,
            code: pending.code
        )
        appDefaults.set(referralAcknowledgementURL?.absoluteString, forKey: ReferralProgram.pendingAcknowledgementURLKey)

        clearPendingReferralInviteFromDefaults()
        pendingReferralInvite = nil
        reloadReferralState()

        notificationCenter.post(name: .profileDidUpdate, object: nil)
        lastMessage = "招待報酬を受け取りました（チケット+\(ReferralProgram.inviteeRewardTickets)）"
    }

    func clearReferralAcknowledgementURL() {
        referralAcknowledgementURL = nil
        appDefaults.removeObject(forKey: ReferralProgram.pendingAcknowledgementURLKey)
    }

    func requestPushNotificationPermission() {
        Task { @MainActor in
            do {
                let granted = try await userNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    if !pushNotificationsEnabled {
                        pushNotificationsEnabled = true
                    }
                    lastMessage = "通知を有効化しました"
                } else {
                    lastMessage = "通知が許可されていません"
                }
                refreshPushNotificationAuthorizationStatus()
            } catch {
                lastMessage = "通知許可の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func applyRecommendedPushNotificationPreset() {
        applyOnboardingNotificationPlan(.recommended, shouldRequestPermission: false)
        lastMessage = "おすすめの通知設定を適用しました"
    }

    func applyMinimalPushNotificationPreset() {
        let plan = OnboardingNotificationPlan(
            isEnabled: true,
            promptUpdateEnabled: true,
            missionEnabled: false,
            streakReminderEnabled: true,
            weeklyTrendEnabled: false,
            requestPermission: false
        )
        applyOnboardingNotificationPlan(plan, shouldRequestPermission: false)
        lastMessage = "最小限の通知設定を適用しました"
    }

    func refreshPushNotificationAuthorizationStatus() {
        Task { @MainActor in
            let settings = await userNotificationCenter.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                pushAuthorizationStatusText = "未許可（未選択）"
            case .denied:
                pushAuthorizationStatusText = "拒否（設定アプリで変更してください）"
            case .authorized:
                pushAuthorizationStatusText = "許可済み"
            case .provisional:
                pushAuthorizationStatusText = "仮許可"
            case .ephemeral:
                pushAuthorizationStatusText = "一時許可"
            @unknown default:
                pushAuthorizationStatusText = "不明"
            }
        }
    }

    private func applyOnboardingNotificationPlan(
        _ plan: OnboardingNotificationPlan,
        shouldRequestPermission: Bool = true
    ) {
        isApplyingNotificationPreferences = true
        pushNotificationsEnabled = plan.isEnabled
        pushPromptUpdateEnabled = plan.promptUpdateEnabled
        pushMissionEnabled = plan.missionEnabled
        pushStreakReminderEnabled = plan.streakReminderEnabled
        pushWeeklyTrendEnabled = plan.weeklyTrendEnabled
        isApplyingNotificationPreferences = false
        persistNotificationPreferencesIfNeeded()

        if shouldRequestPermission, plan.requestPermission, plan.isEnabled {
            requestPushNotificationPermission()
        }
    }

    var normalizedDisplayNamePreview: String {
        normalizedDisplayName(displayName)
    }

    var isDisplayNameChanged: Bool {
        normalizedDisplayNamePreview != displayNameSavedValue
    }

    var displayNameHelpText: String {
        let raw = displayName
        let normalized = normalizedDisplayNamePreview
        let max = UserProfile.maxDisplayNameLength

        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "空欄は「\(Self.defaultDisplayName)」として保存されます"
        }
        if normalized != raw.trimmingCharacters(in: .whitespacesAndNewlines) {
            return "保存時に「\(normalized)」へ整形されます（最大\(max)文字）"
        }
        return "表示名は公開プロフィールとして使われます（最大\(max)文字）"
    }

    var profileSummaryText: String {
        let shortId = userId.isEmpty ? "-" : String(userId.suffix(8))
        return "\(displayNameSavedValue) / ID: \(shortId)"
    }

    var shareProfileText: String {
        """
        MyDailyPhrase
        Name: \(displayNameSavedValue)
        User ID: \(userId)
        """
    }

    var referralInviteShareText: String {
        """
        MyDailyPhrase 招待コード: \(referralCode)
        一緒に続けよう。招待成立でお互いチケット+\(ReferralProgram.inviteeRewardTickets)。
        """
    }

    var referralAcknowledgementShareText: String {
        """
        招待承認リンクです。開いて報酬を受け取ってください。
        招待コード: \(referralCode)
        """
    }

    var hasPendingReferralInvite: Bool {
        pendingReferralInvite != nil
    }

    var referralProgressSummaryText: String {
        "承認済み: \(referralAcceptedCount)件 / 招待報酬受取: \(referralClaimedCount)件"
    }

    var pushNotificationSummaryText: String {
        "通知は、お題更新・ミッション達成・連続記録リマインド・今週急上昇（Creator Pass向け）に利用します。"
    }

    var pushPermissionDisclosureText: String {
        "通知設定はこの画面でいつでも変更できます。不要な通知だけ個別にOFFにできます。"
    }

    var notificationABDashboardRows: [NotificationABDashboardRow] {
        // Force recomputation when scheduler posts AB metric updates.
        _ = notificationABDashboardVersion
        return [
            makeNotificationABDashboardRow(for: .seasonMilestoneReady),
            makeNotificationABDashboardRow(for: .seasonMilestoneReminder)
        ]
    }

    var notificationABDashboardHintText: String {
        "開封率=通知を開いた割合 / 復帰率=通知後24時間以内にアプリへ戻った割合。下のカードでは文言A/Bの実測に加えて、曜日別・時間帯別の実測値を表示します。"
    }

    var securityAuditReportText: String {
        if filteredSecurityAuditTrail.isEmpty {
            return "Security Log: empty"
        }
        let lines = filteredSecurityAuditTrail.map { event in
            "[\(formattedAuditDate(event.occurredAt))] \(event.category.rawValue)/\(event.kind.rawValue) [\(event.severity.rawValue)] \(event.title) provider=\(event.provider ?? "-") actor=\(event.actorHint ?? "-") detail=\(event.detail)"
        }
        return lines.joined(separator: "\n")
    }

    var securityLogFilterHint: String {
        switch securityLogFilter {
        case .all:
            return "選択カテゴリのすべての操作ログ"
        case .linked:
            return "連携成功ログ"
        case .unlinked:
            return "連携解除ログ"
        case .revoked:
            return "失効/未検出ログ"
        case .error:
            return "検証エラーや失敗ログ"
        }
    }

    var securityRetentionPolicyText: String {
        "Security Logは通常\(securityLogRetentionDays)日を目安に保持し、上限\(securityLogRetentionMaxDays)日で運用します。"
    }

    private var profileRecoveryMarkerDate: Date? {
        let ts = appDefaults.double(forKey: profileRecoveryMarkerKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private var hasCorruptProfileSnapshot: Bool {
        appDefaults.data(forKey: profileCorruptStoreKey) != nil
    }

    var releaseReadinessChecks: [ReleaseReadinessCheck] {
        let externalOAuthEnabled = !oauthConfiguredProviders.isEmpty
        let backendDetail: String
        let backendStatus: ReleaseReadinessStatus
        if externalOAuthEnabled {
            if isServerAuthVerificationConfigured {
                backendStatus = .ready
                backendDetail = "外部ログイン検証API: \(serverAuthEndpointHost ?? "(host不明)")"
            } else {
                backendStatus = .missing
                backendDetail = "外部ログイン検証APIが未設定（Info.plist: AUTH_BACKEND_VERIFY_ENDPOINT）"
            }
        } else {
            backendStatus = .ready
            backendDetail = "外部OAuthログインが無効化されているため、認証バックエンドは必須ではありません"
        }

        let termsStatus: ReleaseReadinessStatus = termsOfServiceURLValue == nil ? .missing : .ready
        let termsDetail = termsOfServiceURLValue?.absoluteString ?? "利用規約URLが未設定（LEGAL_TERMS_URL）"

        let privacyStatus: ReleaseReadinessStatus = privacyPolicyURLValue == nil ? .missing : .ready
        let privacyDetail = privacyPolicyURLValue?.absoluteString ?? "プライバシーポリシーURLが未設定（LEGAL_PRIVACY_POLICY_URL）"

        let retentionStatus: ReleaseReadinessStatus = securityLogRetentionDays > 180 ? .warning : .ready
        let retentionDetail = "現在 \(securityLogRetentionDays)日保持 / 上限 \(securityLogRetentionMaxDays)日"

        let devVerifierStatus: ReleaseReadinessStatus = isDevelopmentVerifierEnabled ? .warning : .ready
        let devVerifierDetail = isDevelopmentVerifierEnabled
            ? "開発用 dev_ トークン検証が有効です（Releaseでは無効化推奨）"
            : "開発用 dev_ トークン検証は無効です"

        let callbackStatus: ReleaseReadinessStatus
        let callbackDetail: String
        if let callbackScheme = oauthCallbackScheme {
            if isOAuthCallbackSchemeRegistered {
                callbackStatus = .ready
                callbackDetail = "OAuth callback scheme: \(callbackScheme)"
            } else {
                callbackStatus = .missing
                callbackDetail = "OAuth callback scheme \(callbackScheme) が未登録（Info.plist: CFBundleURLTypes）"
            }
        } else {
            callbackStatus = .missing
            callbackDetail = "OAuth callback scheme が未設定（AUTH_OAUTH_CALLBACK_SCHEME）"
        }

        let googleOAuthStatus: ReleaseReadinessStatus = .ready
        let googleOAuthDetail = oauthConfiguredProviders.contains(.google)
            ? "Google OAuth開始URLを構成済み"
            : "Googleログインはこのリリースでは無効化されています"

        let xOAuthStatus: ReleaseReadinessStatus = .ready
        let xOAuthDetail = oauthConfiguredProviders.contains(.x)
            ? "X OAuth開始URLを構成済み"
            : "Xログインはこのリリースでは無効化されています"

        let manualTokenStatus: ReleaseReadinessStatus = allowsManualExternalAuthTokenInput ? .warning : .ready
        let manualTokenDetail = allowsManualExternalAuthTokenInput
            ? "手動トークン入力が有効（DEBUG限定運用）"
            : "手動トークン入力は無効"

        let loginGateStatus: ReleaseReadinessStatus = isLoginBypassEnabled ? .missing : .ready
        let loginGateDetail = isLoginBypassEnabled
            ? "ログイン必須導線が無効化されています（UITEST_BYPASS_LOGIN）"
            : "初回ログイン必須導線は有効です"

        let knownDecorationIds = Set(CardDecorationCatalog.all.map(\.id))
        let invalidOwnedDecorationCount = ownedDecorationIds.filter { !knownDecorationIds.contains($0) }.count
        let selectedDecorationIsKnown = knownDecorationIds.contains(selectedDecorationId)
        let profileDataStatus: ReleaseReadinessStatus = (invalidOwnedDecorationCount > 0 || !selectedDecorationIsKnown) ? .warning : .ready
        let profileDataDetail: String = {
            if profileDataStatus == .ready {
                return "プロフィール整合性: 装飾データは正常です"
            }
            return "プロフィール整合性: 未知の装飾ID \(invalidOwnedDecorationCount)件 / 選択ID \(selectedDecorationId)"
        }()

        let profileRecoveryStatus: ReleaseReadinessStatus
        let profileRecoveryDetail: String
        if let recoveredAt = profileRecoveryMarkerDate {
            profileRecoveryStatus = .warning
            profileRecoveryDetail = "プロフィール復旧履歴あり: \(formattedAuditDate(recoveredAt))（破損スナップショット: \(hasCorruptProfileSnapshot ? "あり" : "なし")）"
        } else if hasCorruptProfileSnapshot {
            profileRecoveryStatus = .warning
            profileRecoveryDetail = "破損スナップショットを検知。最新プロフィール再保存で解消されるか確認してください。"
        } else {
            profileRecoveryStatus = .ready
            profileRecoveryDetail = "プロフィール復旧履歴なし（正常）"
        }

        return [
            .init(id: "backend", title: "認証バックエンド", detail: backendDetail, status: backendStatus, required: externalOAuthEnabled),
            .init(id: "oauthCallback", title: "OAuth Callback", detail: callbackDetail, status: callbackStatus, required: true),
            .init(id: "oauthGoogle", title: "Google OAuth開始URL", detail: googleOAuthDetail, status: googleOAuthStatus, required: false),
            .init(id: "oauthX", title: "X OAuth開始URL", detail: xOAuthDetail, status: xOAuthStatus, required: false),
            .init(id: "loginGate", title: "初回ログイン必須", detail: loginGateDetail, status: loginGateStatus, required: true),
            .init(id: "terms", title: "利用規約", detail: termsDetail, status: termsStatus, required: true),
            .init(id: "privacy", title: "プライバシーポリシー", detail: privacyDetail, status: privacyStatus, required: true),
            .init(id: "profileData", title: "プロフィール整合性", detail: profileDataDetail, status: profileDataStatus, required: false),
            .init(id: "profileRecovery", title: "プロフィール復旧監視", detail: profileRecoveryDetail, status: profileRecoveryStatus, required: false),
            .init(id: "retention", title: "監査ログ保持", detail: retentionDetail, status: retentionStatus, required: false),
            .init(id: "devVerifier", title: "開発用認証バイパス", detail: devVerifierDetail, status: devVerifierStatus, required: false),
            .init(id: "manualToken", title: "手動トークン入力", detail: manualTokenDetail, status: manualTokenStatus, required: false)
        ]
    }

    var releaseReadinessSummaryText: String {
        let checks = releaseReadinessChecks
        let ready = checks.filter { $0.status == .ready }.count
        let warning = checks.filter { $0.status == .warning }.count
        let missing = checks.filter { $0.status == .missing }.count
        let requiredMissing = checks.filter { $0.required && $0.status == .missing }.count
        if requiredMissing == 0 {
            return "提出必須項目は充足（Ready \(ready) / Warning \(warning) / Missing \(missing)）"
        }
        return "提出前に必須\(requiredMissing)項目の対応が必要です（Ready \(ready) / Warning \(warning) / Missing \(missing)）"
    }

    var isSubmissionChecklistPassing: Bool {
        !releaseReadinessChecks.contains { $0.required && $0.status == .missing }
    }

    var releaseReadinessReportText: String {
        let checks = releaseReadinessChecks
        var lines: [String] = [
            "MyDailyPhrase Release Readiness Report",
            "Generated: \(releaseReportTimestampString)",
            "",
            "Summary:",
            releaseReadinessSummaryText,
            ""
        ]

        lines.append("Checks:")
        for check in checks {
            let required = check.required ? "必須" : "任意"
            lines.append("- [\(required)] \(check.title): \(check.status.title)")
            lines.append("  \(check.detail)")
        }

        let notes = legalReadinessNotes
        if !notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            for note in notes {
                lines.append("- \(note)")
            }
        }

        return lines.joined(separator: "\n")
    }

    var legalReadinessNotes: [String] {
        var notes: [String] = [
            "監査ログには、認証連携・ガチャ・コミュニティ操作に関する監査イベントのみを保存します。",
            "ログはこの画面からコピー・削除できます。"
        ]
        if termsOfServiceURLValue == nil {
            notes.append("利用規約URLが未設定です（Info.plist: LEGAL_TERMS_URL）。")
        }
        if privacyPolicyURLValue == nil {
            notes.append("プライバシーポリシーURLが未設定です（Info.plist: LEGAL_PRIVACY_POLICY_URL）。")
        }
        if isDevelopmentVerifierEnabled {
            notes.append("開発用 dev_ トークン検証が有効です。Releaseビルドでは無効化してください。")
        }
        if isLoginBypassEnabled {
            notes.append("ログイン必須導線が無効化されています（UITEST_BYPASS_LOGIN）。提出前に必ず無効化してください。")
        }
        if oauthCallbackScheme != nil && !isOAuthCallbackSchemeRegistered {
            notes.append("OAuth callback scheme が未登録です（Info.plist: CFBundleURLTypes）。")
        }
        if profileRecoveryMarkerDate != nil || hasCorruptProfileSnapshot {
            notes.append("プロフィール復旧監視でWarningが出ています。Profile > Release Readiness の詳細を確認してください。")
        }
        return notes
    }

    private var releaseReportTimestampString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.string(from: Date())
    }

    func securityAuditTitle(_ event: SecurityAuditEvent) -> String {
        let level: String
        switch event.severity {
        case .info:
            level = "INFO"
        case .warning:
            level = "WARN"
        case .error:
            level = "ERROR"
        }
        return "[\(level)] \(event.title)"
    }

    func securityAuditSubtitle(_ event: SecurityAuditEvent) -> String {
        let provider = event.provider ?? "-"
        let actor = event.actorHint ?? "-"
        return "\(formattedAuditDate(event.occurredAt)) / \(event.category.rawValue) / \(provider) / \(actor)\n\(event.detail)"
    }

    private func reloadReferralState() {
        let inviterId = appDefaults.string(forKey: ReferralProgram.pendingInviterIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let inviterName = appDefaults.string(forKey: ReferralProgram.pendingInviterNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let code = appDefaults.string(forKey: ReferralProgram.pendingCodeKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !inviterId.isEmpty, !inviterName.isEmpty, !code.isEmpty {
            pendingReferralInvite = .init(inviterId: inviterId, inviterName: inviterName, code: code)
        } else {
            pendingReferralInvite = nil
        }

        if let ackURLString = appDefaults.string(forKey: ReferralProgram.pendingAcknowledgementURLKey),
           let ackURL = URL(string: ackURLString) {
            referralAcknowledgementURL = ackURL
        } else {
            referralAcknowledgementURL = nil
        }

        referralAcceptedCount = loadStringSet(forKey: ReferralProgram.acceptedInviterIDsKey).count
        referralClaimedCount = loadStringSet(forKey: ReferralProgram.claimedInviteeIDsKey).count
    }

    private func rebuildReferralShareAssets(userId: String, displayName: String) {
        referralCode = ReferralProgram.referralCode(for: userId)
        referralInviteURL = ReferralProgram.inviteURL(
            inviterId: userId,
            inviterName: displayName,
            code: referralCode
        )
    }

    private func configureNotificationPreferenceBindings() {
        $pushNotificationsEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistNotificationPreferencesIfNeeded()
            }
            .store(in: &cancellables)

        $pushPromptUpdateEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistNotificationPreferencesIfNeeded()
            }
            .store(in: &cancellables)

        $pushMissionEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistNotificationPreferencesIfNeeded()
            }
            .store(in: &cancellables)

        $pushStreakReminderEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistNotificationPreferencesIfNeeded()
            }
            .store(in: &cancellables)

        $pushWeeklyTrendEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistNotificationPreferencesIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func configureExternalObservers() {
        notificationCenter.publisher(for: .profileDidUpdate)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .referralPendingDidUpdate)
            .sink { [weak self] _ in
                self?.reloadReferralState()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .notificationABMetricsDidUpdate)
            .sink { [weak self] _ in
                self?.notificationABDashboardVersion += 1
            }
            .store(in: &cancellables)
    }

    private func loadNotificationPreferencesFromDefaults() {
        isApplyingNotificationPreferences = true
        let preferences = AppNotificationSettings.load(from: appDefaults)
        pushNotificationsEnabled = preferences.isEnabled
        pushPromptUpdateEnabled = preferences.promptUpdateEnabled
        pushMissionEnabled = preferences.missionEnabled
        pushStreakReminderEnabled = preferences.streakReminderEnabled
        pushWeeklyTrendEnabled = preferences.weeklyTrendEnabled
        isApplyingNotificationPreferences = false
    }

    private func persistNotificationPreferencesIfNeeded() {
        guard !isApplyingNotificationPreferences else { return }

        let preferences = AppNotificationSettings.Preferences(
            isEnabled: pushNotificationsEnabled,
            promptUpdateEnabled: pushPromptUpdateEnabled,
            missionEnabled: pushMissionEnabled,
            streakReminderEnabled: pushStreakReminderEnabled,
            weeklyTrendEnabled: pushWeeklyTrendEnabled
        )
        AppNotificationSettings.save(preferences, to: appDefaults)
        notificationCenter.post(name: .notificationPreferencesDidUpdate, object: nil)
    }

    private func clearPendingReferralInviteFromDefaults() {
        appDefaults.removeObject(forKey: ReferralProgram.pendingInviterIDKey)
        appDefaults.removeObject(forKey: ReferralProgram.pendingInviterNameKey)
        appDefaults.removeObject(forKey: ReferralProgram.pendingCodeKey)
        appDefaults.removeObject(forKey: ReferralProgram.pendingReceivedAtKey)
    }

    private func loadStringSet(forKey key: String) -> Set<String> {
        let values = appDefaults.stringArray(forKey: key) ?? []
        return Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private func saveStringSet(_ values: Set<String>, forKey key: String) {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        appDefaults.set(normalized, forKey: key)
    }

    private func makeNotificationABDashboardRow(
        for campaign: AppNotificationSettings.NotificationCampaign
    ) -> NotificationABDashboardRow {
        let stats = AppNotificationSettings.loadCampaignStats(for: campaign, from: appDefaults)
        let winner = AppNotificationSettings.recommendedVariant(for: stats)
        let variants = AppNotificationSettings.NotificationVariant.allCases.map { variant in
            let s = stats.stats(for: variant)
            return NotificationABVariantRow(
                id: "\(campaign.rawValue).\(variant.rawValue)",
                label: "文言\(variant.label)",
                sent: s.sent,
                openRateText: percentText(s.openRate),
                returnRateText: percentText(s.returnRate),
                weightedScoreText: percentText(s.weightedScore)
            )
        }

        let optimizationLabel: String = {
            if campaign == .seasonMilestoneReminder {
                return "最適化: 文言\(winner.label) / \(preferredReminderTimingLabel())"
            }
            return "最適化: 文言\(winner.label)"
        }()

        let weekdayRows = makeNotificationABWeekdayRows(for: campaign)
        let timingSlots: [NotificationTimingSlotRow]
        let timingWeekdayRows: [NotificationTimingWeekdayRow]
        if campaign == .seasonMilestoneReminder {
            let globalTiming = AppNotificationSettings.loadReminderTimingStats(from: appDefaults)
            timingSlots = makeNotificationTimingRows(from: globalTiming)
            timingWeekdayRows = makeNotificationTimingWeekdayRows()
        } else {
            timingSlots = []
            timingWeekdayRows = []
        }

        return NotificationABDashboardRow(
            id: campaign.rawValue,
            title: campaign.title,
            optimizationLabel: optimizationLabel,
            confidenceLabel: optimizationConfidenceLabel(for: stats),
            totalSent: stats.totalSent,
            variants: variants,
            weekdayRows: weekdayRows,
            timingSlots: timingSlots,
            timingWeekdayRows: timingWeekdayRows
        )
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func optimizationConfidenceLabel(
        for stats: AppNotificationSettings.NotificationCampaignStats
    ) -> String {
        let minSample = min(stats.a.sent, stats.b.sent)
        switch minSample {
        case 0..<8:
            return "信頼度: 収集中"
        case 8..<20:
            return "信頼度: 中"
        default:
            return "信頼度: 高"
        }
    }

    private func preferredReminderTimingLabel() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let byWeekday = AppNotificationSettings.loadReminderTimingStatsByWeekday(from: appDefaults)
        let weekdayStats = byWeekday["\(weekday)"] ?? .empty
        let stats = weekdayStats.totalSent >= 10
            ? weekdayStats
            : AppNotificationSettings.loadReminderTimingStats(from: appDefaults)
        let slot = AppNotificationSettings.recommendedTimingSlot(for: stats)
        return slot.label
    }

    private func makeNotificationABWeekdayRows(
        for campaign: AppNotificationSettings.NotificationCampaign
    ) -> [NotificationABWeekdayRow] {
        let contextMap = AppNotificationSettings.loadCampaignContextStats(for: campaign, from: appDefaults)
        var aggregateByWeekday: [Int: AppNotificationSettings.NotificationCampaignStats] = [:]

        for (contextKey, stats) in contextMap {
            guard let weekday = weekdayIndex(from: contextKey) else { continue }
            let merged = mergeCampaignStats(aggregateByWeekday[weekday] ?? .empty, stats)
            aggregateByWeekday[weekday] = merged
        }

        return (1...7).compactMap { weekday in
            guard let dayStats = aggregateByWeekday[weekday], dayStats.totalSent > 0 else { return nil }
            let winner = AppNotificationSettings.recommendedVariant(for: dayStats)
            let variants = AppNotificationSettings.NotificationVariant.allCases.map { variant in
                let s = dayStats.stats(for: variant)
                return NotificationABVariantRow(
                    id: "\(campaign.rawValue).weekday\(weekday).\(variant.rawValue)",
                    label: "文言\(variant.label)",
                    sent: s.sent,
                    openRateText: percentText(s.openRate),
                    returnRateText: percentText(s.returnRate),
                    weightedScoreText: percentText(s.weightedScore)
                )
            }
            return NotificationABWeekdayRow(
                id: "\(campaign.rawValue).weekday\(weekday)",
                weekdayLabel: shortWeekdayText(weekday),
                winnerLabel: "最適化: 文言\(winner.label)",
                confidenceLabel: optimizationConfidenceLabel(for: dayStats),
                totalSent: dayStats.totalSent,
                variants: variants
            )
        }
    }

    private func makeNotificationTimingRows(
        from stats: AppNotificationSettings.NotificationTimingStats
    ) -> [NotificationTimingSlotRow] {
        AppNotificationSettings.NotificationTimingSlot.allCases.map { slot in
            let s = stats.stats(for: slot)
            return NotificationTimingSlotRow(
                id: slot.rawValue,
                label: slot.label,
                sent: s.sent,
                openRateText: percentText(s.openRate),
                returnRateText: percentText(s.returnRate),
                weightedScoreText: percentText(s.weightedScore)
            )
        }
    }

    private func makeNotificationTimingWeekdayRows() -> [NotificationTimingWeekdayRow] {
        let map = AppNotificationSettings.loadReminderTimingStatsByWeekday(from: appDefaults)
        return (1...7).compactMap { weekday in
            let stats = map["\(weekday)"] ?? .empty
            guard stats.totalSent > 0 else { return nil }
            let recommended = AppNotificationSettings.recommendedTimingSlot(for: stats)
            return NotificationTimingWeekdayRow(
                id: "timing.weekday\(weekday)",
                weekdayLabel: shortWeekdayText(weekday),
                optimizationLabel: "最適化: \(recommended.label)",
                confidenceLabel: timingOptimizationConfidenceLabel(totalSent: stats.totalSent),
                totalSent: stats.totalSent,
                slots: makeNotificationTimingRows(from: stats)
            )
        }
    }

    private func timingOptimizationConfidenceLabel(totalSent: Int) -> String {
        switch totalSent {
        case 0..<8:
            return "信頼度: 収集中"
        case 8..<20:
            return "信頼度: 中"
        default:
            return "信頼度: 高"
        }
    }

    private func weekdayIndex(from contextKey: String) -> Int? {
        guard contextKey.hasPrefix("w") else { return nil }
        let numericPart = contextKey.dropFirst().prefix { $0.isNumber }
        guard let value = Int(numericPart), (1...7).contains(value) else { return nil }
        return value
    }

    private func shortWeekdayText(_ weekday: Int) -> String {
        switch weekday {
        case 1:
            return "日"
        case 2:
            return "月"
        case 3:
            return "火"
        case 4:
            return "水"
        case 5:
            return "木"
        case 6:
            return "金"
        case 7:
            return "土"
        default:
            return "-"
        }
    }

    private func mergeCampaignStats(
        _ lhs: AppNotificationSettings.NotificationCampaignStats,
        _ rhs: AppNotificationSettings.NotificationCampaignStats
    ) -> AppNotificationSettings.NotificationCampaignStats {
        .init(
            a: .init(
                sent: lhs.a.sent + rhs.a.sent,
                opened: lhs.a.opened + rhs.a.opened,
                returned: lhs.a.returned + rhs.a.returned
            ),
            b: .init(
                sent: lhs.b.sent + rhs.b.sent,
                opened: lhs.b.opened + rhs.b.opened,
                returned: lhs.b.returned + rhs.b.returned
            )
        )
    }

    private func applyProfile(_ p: UserProfile) {
        userId = p.userId
        displayName = p.displayName
        displayNameSavedValue = p.displayName
        ownedDecorationIds = p.ownedDecorationIds
        selectedDecorationId = p.selectedDecorationId
        gachaTickets = p.gachaTickets
        linkedAuthProvider = p.linkedAuthProvider
        linkedAuthUserIdRaw = p.linkedAuthUserId
        linkedAuthUserIdHint = ProfileViewModel.maskedAuthUserId(p.linkedAuthUserId)
        hasCompletedOnboarding = p.hasCompletedOnboarding
        authAuditTrail = p.authAuditTrail
        securityAuditTrail = p.securityAuditTrail
        rebuildReferralShareAssets(userId: p.userId, displayName: p.displayName)
    }

    private static func maskedAuthUserId(_ raw: String?) -> String {
        guard let raw else { return "-" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }
        let suffix = String(trimmed.suffix(6))
        return "***\(suffix)"
    }

    private func makeAuthAudit(
        kind: AuthAuditEventKind,
        provider: String?,
        authUserId: String?,
        message: String
    ) -> AuthAuditEvent {
        let hint = Self.maskedAuthUserId(authUserId)
        let normalizedHint = hint == "-" ? nil : hint
        let normalizedProvider = provider?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return AuthAuditEvent(
            kind: kind,
            provider: normalizedProvider,
            authUserIdHint: normalizedHint,
            message: message
        )
    }

    private func appendAuthAudit(
        kind: AuthAuditEventKind,
        provider: String?,
        authUserId: String?,
        message: String
    ) {
        let p = update(
            appendAuthAuditEvent: makeAuthAudit(
                kind: kind,
                provider: provider,
                authUserId: authUserId,
                message: message
            )
        )
        applyProfile(p)
    }

    private func matchesSecurityFilter(_ event: SecurityAuditEvent) -> Bool {
        switch securityLogFilter {
        case .all:
            return true
        case .linked:
            return event.kind == .authLinked
        case .unlinked:
            return event.kind == .authUnlinked
        case .revoked:
            return event.kind == .authCredentialRevoked || event.kind == .authCredentialNotFound
        case .error:
            return event.severity == .error
                || event.kind == .authCredentialRevoked
                || event.kind == .authCredentialNotFound
                || event.kind == .authVerificationFailed
                || event.kind == .gachaDrawFailed
                || event.kind == .gachaExchangeFailed
        }
    }

    private func matchesSecurityCategoryFilter(_ event: SecurityAuditEvent) -> Bool {
        switch securityLogCategoryFilter {
        case .all:
            return true
        case .auth:
            return event.category == .auth
        case .gacha:
            return event.category == .gacha
        case .community:
            return event.category == .community
        }
    }

    private func canLinkExternalAccount(provider: ExternalAuthProvider) -> Bool {
        if allowsManualExternalAuthTokenInput {
            return true
        }
        guard oauthCallbackScheme != nil else {
            return false
        }
        guard isOAuthCallbackSchemeRegistered else {
            return false
        }
        guard oauthConfiguredProviders.contains(provider) else {
            return false
        }
        return externalAuthTokenBroker?.canHandle(provider: provider) == true
    }

    private func linkExternalAccountUsingServerToken(provider: ExternalAuthProvider) async {
        guard !isLinkingExternalAuth else { return }
        if let current = linkedAuthProvider, current != provider.rawValue {
            appendAuthAudit(
                kind: .providerReplacementBlocked,
                provider: current,
                authUserId: linkedAuthUserIdRaw,
                message: "他プロバイダ連携中のため\(provider.displayName)連携をブロック"
            )
            lastMessage = "\(linkedAuthProviderName) 連携を解除してから\(provider.displayName)に切り替えてください"
            return
        }

        let manualToken = externalAuthVerificationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let token: String
        if !manualToken.isEmpty {
            token = manualToken
        } else if let broker = externalAuthTokenBroker, canLinkExternalAccount(provider: provider) {
            do {
                token = try await broker.fetchToken(for: provider)
            } catch {
                if let brokerError = error as? ExternalAuthTokenBrokerError {
                    lastMessage = "\(provider.displayName) ログインに失敗しました: \(brokerError.localizedDescription)"
                } else {
                    lastMessage = "\(provider.displayName) ログインに失敗しました: \(error.localizedDescription)"
                }
                return
            }
        } else {
            lastMessage = "\(provider.displayName) ログイン設定が不足しています（OAuth開始URL/Callback）"
            return
        }

        isLinkingExternalAuth = true
        defer { isLinkingExternalAuth = false }

        do {
            let verified = try await authTokenVerifier.verify(
                request: ExternalAuthVerificationRequest(provider: provider, token: token)
            )

            let shouldAutoFillName = displayNameSavedValue == Self.defaultDisplayName
            let suggested = (verified.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let displayNameToSave: String? = shouldAutoFillName && !suggested.isEmpty ? suggested : nil

            let p = update(
                displayName: displayNameToSave,
                linkedAuthProvider: verified.provider.rawValue,
                linkedAuthUserId: verified.subject,
                linkedAuthAt: verified.issuedAt,
                hasCompletedOnboarding: false,
                onboardingVersion: 0,
                appendAuthAuditEvent: makeAuthAudit(
                    kind: .linked,
                    provider: verified.provider.rawValue,
                    authUserId: verified.subject,
                    message: "\(verified.provider.displayName) のサーバー検証が成功し連携しました"
                )
            )
            applyProfile(p)
            lastMessage = "\(verified.provider.displayName) 連携を保存しました"
        } catch {
            appendAuthAudit(
                kind: .verificationFailed,
                provider: provider.rawValue,
                authUserId: linkedAuthUserIdRaw,
                message: "\(provider.displayName) サーバー検証失敗: \(error.localizedDescription)"
            )
            lastMessage = "\(provider.displayName) 検証に失敗しました: \(error.localizedDescription)"
        }
    }

    private func formattedAuditDate(_ date: Date) -> String {
        Self.auditDateFormatter.string(from: date)
    }

    private static let auditDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    // MARK: - Decoration ops

    func selectDecoration(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard ownedDecorationIds.contains(trimmed) || trimmed == "classic" else {
            lastMessage = "未所持の装飾は選べません"
            return
        }

        let p = update(selectedDecorationId: trimmed)
        selectedDecorationId = p.selectedDecorationId
        lastMessage = "装飾を「\(displayNameForDecoration(trimmed))」に変更しました"
    }

    func drawFreeGacha() {
        guard gachaTickets > 0 else {
            lastMessage = "無料ガチャ券がありません"
            return
        }

        // 1) 消費
        _ = update(gachaTickets: gachaTickets - 1)
        gachaTickets -= 1

        // 2) 抽選（classic除外 + weight>0 のみ）
        let pool = catalog.filter { $0.weight > 0 }
        guard let hit = weightedPick(pool) else {
            lastMessage = "ガチャ抽選に失敗しました"
            return
        }

        // 3) 付与（重複なら“同じのが出た”扱い。ここは後で欠片などにしても良い）
        var owned = Set(ownedDecorationIds + ["classic"])
        let isNew = !owned.contains(hit.id)
        owned.insert(hit.id)

        let newOwned = Array(owned)
        let p = update(ownedDecorationIds: newOwned)

        ownedDecorationIds = p.ownedDecorationIds

        if isNew {
            // 新規獲得時は自動で選択しても良い（好み）
            let p2 = update(selectedDecorationId: hit.id)
            selectedDecorationId = p2.selectedDecorationId
            lastMessage = "🎉 新しい装飾「\(hit.name)」を獲得しました（自動で適用）"
        } else {
            lastMessage = "「\(hit.name)」が出ました（重複）"
        }
    }

    private func weightedPick(_ items: [Decoration]) -> Decoration? {
        let sum = items.reduce(0) { $0 + max(0, $1.weight) }
        guard sum > 0 else { return nil }
        var r = Int.random(in: 0..<sum)
        for it in items {
            let w = max(0, it.weight)
            if r < w { return it }
            r -= w
        }
        return items.last
    }

    func displayNameForDecoration(_ id: String) -> String {
        CardDecorationCatalog.byId(id)?.name ?? id
    }

    private func normalizedDisplayName(_ raw: String) -> String {
        let filteredScalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let noControl = String(String.UnicodeScalarView(filteredScalars))
        let collapsed = noControl
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let clipped = String(collapsed.prefix(UserProfile.maxDisplayNameLength))
        return clipped.isEmpty ? Self.defaultDisplayName : clipped
    }
}
