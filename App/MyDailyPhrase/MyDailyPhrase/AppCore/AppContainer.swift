import Foundation
import Domain
import Presentation
import Data

final class AppContainer {
    static let preferredAppGroupID = "group.jp.catloverbot.MyDailyPhrase"
    static let legacyAppGroupIDs = ["group.MyDailyPhrase"]
    private static let unlimitedGachaTicketUserIDs: Set<String> = [
        "a26f5e8c-47ec-4d5e-bcbf-95ea47d9bbee"
    ]

    let appGroupID: String
    private let timeZone: TimeZone = .current

    // ✅ AppGroup UserDefaults を一箇所で確定（保険で standard fallback）
    private let appGroupDefaults: UserDefaults

    // ===== Core =====
    private let entryRepo: EntryRepository
    private let promptRepo: PromptRepository

    private let enrichEntry: EnrichEntryUseCase
    private let toggleFavorite: ToggleFavoriteUseCase

    // ===== Profile / Challenge / Reaction =====
    private let profileRepo: UserProfileRepository
    private let communityTemplateRepo: CommunityTemplateRepository
    private let challengeEventRepo: ChallengeEventRepository
    private let reactionEventRepo: ReactionEventRepository

    private let getMyProfile: GetMyProfileUseCase
    private let updateMyProfile: UpdateMyProfileUseCase
    private let listCommunities: ListCommunitiesUseCase
    private let saveCommunityTemplate: SaveCommunityTemplateUseCase
    private let joinCommunity: JoinCommunityUseCase
    private let leaveCommunity: LeaveCommunityUseCase
    private let getCommunityResponse: GetCommunityResponseUseCase
    private let saveCommunityResponse: SaveCommunityResponseUseCase

    // ✅ Gacha UseCases（強化）
    private let drawDecorationGacha: DrawDecorationGachaUseCase
    private let grantDailyFreeTicket: GrantDailyFreeTicketUseCase

    private let createChallengeLink: CreateChallengeLinkUseCase
    private let receiveChallengeLink: ReceiveChallengeLinkUseCase
    private let listInboxChallenges: ListInboxChallengesUseCase
    private let listOutboxChallenges: ListOutboxChallengesUseCase

    private let createReactionLink: CreateReactionLinkUseCase
    private let receiveReactionLink: ReceiveReactionLinkUseCase
    private let listInboxReactions: ListInboxReactionsUseCase
    private let listOutboxReactions: ListOutboxReactionsUseCase

    // ===== Room =====
    private let roomRepo: RoomMembershipRepository
    private let roomInviteRepo: RoomInviteEventRepository

    private let listRooms: ListRoomsUseCase
    private let joinRoom: JoinRoomUseCase
    private let leaveRoom: LeaveRoomUseCase

    private let createRoomInviteLink: CreateRoomInviteLinkUseCase
    private let receiveRoomInviteLink: ReceiveRoomInviteLinkUseCase
    private let listRoomInvites: ListRoomInvitesUseCase

    // ===== Comment =====
    private let commentEventRepo: CommentEventRepository
    private let createCommentLink: CreateCommentLinkUseCase
    private let receiveCommentLink: ReceiveCommentLinkUseCase
    private let listInboxComments: ListInboxCommentsUseCase
    private let listOutboxComments: ListOutboxCommentsUseCase

    // ===== Import Challenge → Entry =====
    private let importChallengeToEntry: ImportChallengeToEntryUseCase
    let launchConfiguration: AppLaunchRuntimeConfiguration
    private lazy var authRuntimeConfiguration: ExternalAuthRuntimeConfiguration = ExternalAuthRuntimeConfiguration.load()

    init(appGroupID: String = AppContainer.preferredAppGroupID) {
        Self.debugLaunchLog("[Launch] AppContainer init start")
        Self.migrateLegacyAppGroupDataIfNeeded(
            preferredGroupID: appGroupID,
            legacyGroupIDs: Self.legacyAppGroupIDs
        )
        Self.resetAppDataIfNeeded(preferredGroupID: appGroupID)
        self.appGroupID = appGroupID
        let resolvedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
        self.appGroupDefaults = resolvedDefaults
        self.launchConfiguration = AppLaunchRuntimeConfiguration.load()
#if DEBUG
        Self.seedNotificationABMetricsForUITestIfNeeded(defaults: resolvedDefaults)
#endif
        let forceUnlimitedForUITest = Self.boolEnv("UITEST_FORCE_UNLIMITED_GACHA")

        // Core repos
        self.promptRepo = LocalPromptRepository()
        self.entryRepo = AppGroupEntryRepository(appGroupID: appGroupID)

        // Enrichment
        let service: TextEnrichmentService = HeuristicTextEnrichmentService()
        self.enrichEntry = EnrichEntryUseCase(service: service, locale: .current)
        self.toggleFavorite = ToggleFavoriteUseCase(entryRepo: entryRepo)

        // Profile / events repos
        self.profileRepo = AppGroupUserProfileRepository(appGroupID: appGroupID)
        self.communityTemplateRepo = AppGroupCommunityTemplateRepository(appGroupID: appGroupID)
        self.challengeEventRepo = AppGroupChallengeEventRepository(appGroupID: appGroupID)
        self.reactionEventRepo = AppGroupReactionEventRepository(appGroupID: appGroupID)

        self.getMyProfile = GetMyProfileUseCase(repo: profileRepo)
        self.updateMyProfile = UpdateMyProfileUseCase(repo: profileRepo)
        self.listCommunities = ListCommunitiesUseCase(repo: communityTemplateRepo)
        self.saveCommunityTemplate = SaveCommunityTemplateUseCase(repo: communityTemplateRepo)
        self.joinCommunity = JoinCommunityUseCase(repo: communityTemplateRepo)
        self.leaveCommunity = LeaveCommunityUseCase(repo: communityTemplateRepo)
        self.getCommunityResponse = GetCommunityResponseUseCase(repo: communityTemplateRepo)
        self.saveCommunityResponse = SaveCommunityResponseUseCase(repo: communityTemplateRepo)
#if DEBUG
        Self.seedLinkedAuthForUITestIfNeeded(get: self.getMyProfile, update: self.updateMyProfile)
#endif
        let unlimitedTicketUserIDs = Self.unlimitedGachaTicketUserIDs

        // ✅ Gacha UseCases
        self.drawDecorationGacha = DrawDecorationGachaUseCase(
            get: getMyProfile,
            update: updateMyProfile,
            pityThreshold: 80,
            hasUnlimitedTicketsForUserId: { userId in
                let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return forceUnlimitedForUITest || unlimitedTicketUserIDs.contains(normalized)
            }
        )
        self.grantDailyFreeTicket = GrantDailyFreeTicketUseCase(
            get: getMyProfile,
            update: updateMyProfile,
            timeZone: timeZone,
            dailyBonusTickets: { [groupID = appGroupID] in
                let defaults = UserDefaults(suiteName: groupID) ?? .standard
                return defaults.bool(forKey: IAPStore.creatorPassEntitlementKey)
                    ? IAPStore.creatorPassDailyBonusTickets
                    : 0
            }
        )

        self.createChallengeLink = CreateChallengeLinkUseCase(profileUC: getMyProfile, events: challengeEventRepo)
        self.receiveChallengeLink = ReceiveChallengeLinkUseCase(events: challengeEventRepo)
        self.listInboxChallenges = ListInboxChallengesUseCase(events: challengeEventRepo)
        self.listOutboxChallenges = ListOutboxChallengesUseCase(events: challengeEventRepo)

        self.createReactionLink = CreateReactionLinkUseCase(profileUC: getMyProfile, events: reactionEventRepo)
        self.receiveReactionLink = ReceiveReactionLinkUseCase(events: reactionEventRepo)
        self.listInboxReactions = ListInboxReactionsUseCase(events: reactionEventRepo)
        self.listOutboxReactions = ListOutboxReactionsUseCase(events: reactionEventRepo)

        // Room
        self.roomRepo = AppGroupRoomMembershipRepository(appGroupID: appGroupID)
        self.roomInviteRepo = AppGroupRoomInviteEventRepository(appGroupID: appGroupID)

        self.listRooms = ListRoomsUseCase(repo: roomRepo)
        self.joinRoom = JoinRoomUseCase(repo: roomRepo)
        self.leaveRoom = LeaveRoomUseCase(repo: roomRepo)

        self.createRoomInviteLink = CreateRoomInviteLinkUseCase(profileUC: getMyProfile, events: roomInviteRepo)
        self.receiveRoomInviteLink = ReceiveRoomInviteLinkUseCase(events: roomInviteRepo)
        self.listRoomInvites = ListRoomInvitesUseCase(events: roomInviteRepo)

        // Comment
        self.commentEventRepo = AppGroupCommentEventRepository(appGroupID: appGroupID)
        self.createCommentLink = CreateCommentLinkUseCase(profileUC: getMyProfile, events: commentEventRepo)
        self.receiveCommentLink = ReceiveCommentLinkUseCase(events: commentEventRepo)
        self.listInboxComments = ListInboxCommentsUseCase(events: commentEventRepo)
        self.listOutboxComments = ListOutboxCommentsUseCase(events: commentEventRepo)

        // Import Challenge → Entry
        self.importChallengeToEntry = ImportChallengeToEntryUseCase(entryRepo: entryRepo)
        Self.debugLaunchLog(
            "[Launch] AppContainer init end",
            "safeMode=\(launchConfiguration.safeModeEnabled)",
            "auth=\(launchConfiguration.effectiveAuthEnabled)"
        )
    }

    // MARK: - Deep link handling

    func handleIncomingDeepLink(_ url: URL) {
        if handleReferralDeepLink(url) {
            return
        }

        // 1) Room
        if url.scheme == RoomLinkCodec.scheme, let host = url.host {
            do {
                switch host {
                case RoomLinkCodec.hostInvite:
                    _ = try receiveRoomInviteLink(url: url)
                    debugLog("[DeepLink] received room_invite:", url.absoluteString)
                    return

                case RoomLinkCodec.hostJoin:
                    let join = try RoomLinkCodec.decodeJoin(url)
                    _ = joinRoom(roomId: join.roomId, roomName: join.roomName)
                    debugLog("[DeepLink] received room_join:", url.absoluteString)
                    return

                default:
                    break
                }
            } catch {
                debugLog("[DeepLink] room failed:", error.localizedDescription)
                return
            }
        }

        // 2) Comment
        if url.scheme == CommentLinkCodec.scheme, url.host == CommentLinkCodec.hostComment {
            do {
                _ = try receiveCommentLink(url: url)
                debugLog("[DeepLink] received comment:", url.absoluteString)
            } catch {
                debugLog("[DeepLink] comment failed:", error.localizedDescription)
            }
            return
        }

        // 3) Challenge / Reaction
        do {
            switch try DeepLinkCodec.parse(url) {
            case .challenge:
                _ = try receiveChallengeLink(url: url)
                debugLog("[DeepLink] received challenge:", url.absoluteString)

            case .react:
                _ = try receiveReactionLink(url: url)
                debugLog("[DeepLink] received react:", url.absoluteString)
            }
        } catch {
            debugLog("[DeepLink] failed:", error.localizedDescription)
        }
    }

    private func handleReferralDeepLink(_ url: URL) -> Bool {
        if let invite = ReferralProgram.parseInvite(url: url) {
            let me = getMyProfile()
            if invite.inviterId == me.userId {
                debugLog("[DeepLink] referral invite ignored (self)")
                return true
            }

            appGroupDefaults.set(invite.inviterId, forKey: ReferralProgram.pendingInviterIDKey)
            appGroupDefaults.set(invite.inviterName, forKey: ReferralProgram.pendingInviterNameKey)
            appGroupDefaults.set(invite.code, forKey: ReferralProgram.pendingCodeKey)
            appGroupDefaults.set(Date().timeIntervalSince1970, forKey: ReferralProgram.pendingReceivedAtKey)
            NotificationCenter.default.post(name: .referralPendingDidUpdate, object: nil)
            debugLog("[DeepLink] referral invite received:", invite.code)
            return true
        }

        if let acknowledgement = ReferralProgram.parseAcknowledgement(url: url) {
            let me = getMyProfile()
            guard acknowledgement.inviterId == me.userId else {
                debugLog("[DeepLink] referral ack ignored (different inviter)")
                return true
            }
            guard acknowledgement.inviteeId != me.userId else {
                debugLog("[DeepLink] referral ack ignored (self invitee)")
                return true
            }

            var claimedInviteeIDs = loadStringSet(forKey: ReferralProgram.claimedInviteeIDsKey)
            guard !claimedInviteeIDs.contains(acknowledgement.inviteeId) else {
                debugLog("[DeepLink] referral ack ignored (already claimed)")
                return true
            }

            claimedInviteeIDs.insert(acknowledgement.inviteeId)
            saveStringSet(claimedInviteeIDs, forKey: ReferralProgram.claimedInviteeIDsKey)

            let actorHint = me.userId.isEmpty ? nil : String(me.userId.suffix(8))
            _ = updateMyProfile(
                appendSecurityAuditEvent: SecurityAuditEvent(
                    category: .community,
                    kind: .communityReferralRewardClaimed,
                    title: "招待報酬（招待者）",
                    detail: "invitee=\(acknowledgement.inviteeName) code=\(acknowledgement.code)",
                    actorHint: actorHint,
                    metadata: [
                        "inviteeId": acknowledgement.inviteeId
                    ]
                ),
                addGachaTickets: ReferralProgram.inviterRewardTickets
            )
            NotificationCenter.default.post(name: .profileDidUpdate, object: nil)
            debugLog("[DeepLink] referral ack rewarded:", acknowledgement.inviteeId)
            return true
        }

        return false
    }

    // MARK: - Share URL builders

    func makeChallengeShareURL(dateKey: String, prompt: String, room: String? = nil, chainId: String? = nil) -> URL? {
        createChallengeLink(dateKey: dateKey, prompt: prompt, room: room, chainId: chainId)
    }

    func makeReactionShareURL(emoji: String, toChallengeId: String?, room: String? = nil, chainId: String? = nil) -> URL? {
        createReactionLink(emoji: emoji, toChallengeId: toChallengeId, room: room, chainId: chainId)
    }

    func makeRoomInviteURL(roomId: String, roomName: String?) -> URL? {
        createRoomInviteLink(roomId: roomId, roomName: roomName)
    }

    func makeRoomJoinURL(roomId: String, roomName: String?) -> URL? {
        let me = getMyProfile()
        let link = RoomJoinLink(roomId: roomId, roomName: roomName, userId: me.userId, name: me.displayName)
        return RoomLinkCodec.encodeJoin(link)
    }

    func makeCommentShareURL(text: String, toChallengeId: String?, room: String?, chainId: String?) -> URL? {
        createCommentLink(text: text, toChallengeId: toChallengeId, room: room, chainId: chainId)
    }

    // MARK: - Presentation VMs

    func makeHomeViewModel() -> Presentation.HomeViewModel {
        let getTodayEntry = GetTodayEntryUseCase(promptRepo: promptRepo, entryRepo: entryRepo, timeZone: timeZone)
        let saveTodayAnswer = SaveTodayAnswerUseCase(promptRepo: promptRepo, entryRepo: entryRepo, timeZone: timeZone)
        let computeStreak = ComputeStreakUseCase(entryRepo: entryRepo, timeZone: timeZone)
        let countAnsweredEntriesInCurrentMonth = CountAnsweredEntriesInCurrentMonthUseCase(
            entryRepo: entryRepo,
            timeZone: timeZone
        )

        return Presentation.HomeViewModel(
            getTodayEntry: getTodayEntry,
            saveTodayAnswer: saveTodayAnswer,
            computeStreak: computeStreak,
            countAnsweredEntriesInCurrentMonth: countAnsweredEntriesInCurrentMonth
        )
    }

    func makeHistoryViewModel() -> Presentation.HistoryViewModel {
        let listEntries = ListEntriesUseCase(entryRepo: entryRepo)
        let deleteEntry = DeleteEntryUseCase(entryRepo: entryRepo)
        return Presentation.HistoryViewModel(listEntries: listEntries, deleteEntry: deleteEntry)
    }

    func makeSettingsViewModel() -> Presentation.SettingsViewModel {
        let deleteAllEntries = DeleteAllEntriesUseCase(entryRepo: entryRepo)
        let reminderManager = DailyReminderManager(defaults: appGroupDefaults)
        return Presentation.SettingsViewModel(
            appVersionText: AppMetadata.versionBuildText,
            privacyPolicyURL: AppLinks.privacyPolicy,
            supportURL: AppLinks.support,
            deleteAllEntries: deleteAllEntries,
            loadReminderSettings: {
                await reminderManager.loadSnapshot()
            },
            updateReminderSettings: { snapshot in
                await reminderManager.update(snapshot: snapshot)
            },
            loadDecorationArtworkPreviewState: { [getMyProfile] in
                let profile = getMyProfile()
                return Presentation.DecorationArtworkPreviewState(
                    ownedDecorationIDs: profile.ownedDecorationIds.sorted(),
                    equippedDecorationID: profile.selectedDecorationId
                )
            },
            grantLocalTestTickets: { [updateMyProfile] amount in
                _ = updateMyProfile(addGachaTickets: amount)
                NotificationCenter.default.post(name: .profileDidUpdate, object: nil)
            }
        )
    }

    func makeAuthViewModel() -> AppAuthViewModel {
        let runtimeConfig = authRuntimeConfiguration
        return AppAuthViewModel(
            authRepository: makeAuthRepository(runtimeConfig: runtimeConfig),
            getMyProfile: getMyProfile,
            updateMyProfile: updateMyProfile,
            authEnabled: launchConfiguration.effectiveAuthEnabled,
            signInWithAppleEnabled: launchConfiguration.signInWithAppleEnabled,
            googleSignInEnabled: launchConfiguration.googleSignInEnabled,
            guestModeEnabled: launchConfiguration.guestModeEnabled,
            adminMenuEnabled: launchConfiguration.adminMenuEnabled,
            termsOfServiceURL: runtimeConfig.termsOfServiceURL ?? AppLinks.termsOfService,
            privacyPolicyURL: runtimeConfig.privacyPolicyURL ?? AppLinks.privacyPolicy,
            loadPersistedAuthError: { [suiteName = appGroupID] in
                let defaults = UserDefaults(suiteName: suiteName) ?? .standard
                return defaults.string(forKey: LocalAuthRepository.lastDiagnosticsErrorKey)
            }
        )
    }

    func makeReviewViewModel() -> Presentation.ReviewViewModel {
        let listEntries = ListEntriesUseCase(entryRepo: entryRepo)
        return Presentation.ReviewViewModel(listEntries: listEntries, enrichEntry: enrichEntry, timeZone: timeZone)
    }

    // ✅ ガチャVM（強化版の依存を注入）
    func makeGachaViewModel() -> GachaViewModel {
        let unlimitedTicketUserIDs = Self.unlimitedGachaTicketUserIDs
        let forceUnlimitedForUITest = Self.boolEnv("UITEST_FORCE_UNLIMITED_GACHA")
        let forceDrawErrorOnceForUITest = Self.boolEnv("UITEST_GACHA_FORCE_DRAW_ERROR_ONCE")
        return GachaViewModel(
            getMyProfile: getMyProfile,
            updateMyProfile: updateMyProfile,
            drawDecorationGacha: drawDecorationGacha,
            grantDailyFreeTicket: grantDailyFreeTicket,
            hasUnlimitedTicketsForUserId: { userId in
                let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return forceUnlimitedForUITest || unlimitedTicketUserIDs.contains(normalized)
            },
            forceDrawErrorOnceForUITest: forceDrawErrorOnceForUITest
        )
    }

    func makeCommunityLiteViewModel() -> CommunityLiteViewModel {
        let computeStreak = ComputeStreakUseCase(entryRepo: entryRepo, timeZone: timeZone)
        return CommunityLiteViewModel(
            getMyProfile: getMyProfile,
            updateMyProfile: updateMyProfile,
            computeStreak: computeStreak,
            listCommunities: listCommunities,
            saveCommunityTemplate: saveCommunityTemplate,
            joinCommunity: joinCommunity,
            leaveCommunity: leaveCommunity,
            getCommunityResponse: getCommunityResponse,
            saveCommunityResponse: saveCommunityResponse,
            defaults: appGroupDefaults,
            timeZone: timeZone,
            creatorEntitlementService: CreatorEntitlementService(defaults: appGroupDefaults)
        )
    }

    // MARK: - App VMs

    func makeCommunityViewModel() -> CommunityViewModel {
        CommunityViewModel(
            getMyProfile: getMyProfile,
            updateMyProfile: updateMyProfile,
            listInboxChallenges: listInboxChallenges,
            listOutboxChallenges: listOutboxChallenges,
            listInboxReactions: listInboxReactions,
            listOutboxReactions: listOutboxReactions,

            listRooms: listRooms,
            joinRoom: joinRoom,
            leaveRoom: leaveRoom,
            listRoomInvites: listRoomInvites,
            makeRoomInviteURL: { [weak self] roomId, roomName in
                self?.makeRoomInviteURL(roomId: roomId, roomName: roomName)
            },
            makeRoomJoinURL: { [weak self] roomId, roomName in
                self?.makeRoomJoinURL(roomId: roomId, roomName: roomName)
            },
            makeChallengeShareURL: { [weak self] dateKey, prompt in
                self?.makeChallengeShareURL(dateKey: dateKey, prompt: prompt)
            },

            createCommentLink: createCommentLink,
            listInboxComments: listInboxComments,
            listOutboxComments: listOutboxComments,

            makeReactionURL: { [weak self] emoji, toChallengeId, room, chainId in
                self?.makeReactionShareURL(emoji: emoji, toChallengeId: toChallengeId, room: room, chainId: chainId)
            },
            importChallengeToEntry: importChallengeToEntry,
            isCreatorPassActiveProvider: { [groupID = appGroupID] in
                let defaults = UserDefaults(suiteName: groupID) ?? .standard
                return defaults.bool(forKey: IAPStore.creatorPassEntitlementKey)
            },
            defaults: appGroupDefaults
        )
    }

    func makeProfileViewModel() -> ProfileViewModel {
        guard launchConfiguration.effectiveAuthEnabled else {
            return ProfileViewModel(
                get: getMyProfile,
                update: updateMyProfile,
                authTokenVerifier: BackendPendingAuthTokenVerifier(),
                termsOfServiceURL: AppLinks.termsOfService,
                privacyPolicyURL: AppLinks.privacyPolicy,
                defaultSecurityLogRetentionDays: 90,
                maxSecurityLogRetentionDays: 365,
                isServerAuthVerificationConfigured: false,
                serverAuthEndpointHost: nil,
                isDevelopmentVerifierEnabled: false,
                externalAuthTokenBroker: nil,
                oauthConfiguredProviders: [],
                oauthCallbackScheme: nil,
                isOAuthCallbackSchemeRegistered: false,
                allowsManualExternalAuthTokenInput: false,
                isLoginBypassEnabled: false,
                appDefaults: appGroupDefaults
            )
        }

        let runtimeConfig = authRuntimeConfiguration
        let callbackScheme: String? = {
#if DEBUG
            if let override = Self.stringEnv("UITEST_AUTH_OAUTH_CALLBACK_SCHEME_OVERRIDE") {
                return override.lowercased()
            }
#endif
            return runtimeConfig.oauthCallbackScheme
        }()
        let registeredSchemes = Bundle.main.registeredURLSchemes
        let callbackSchemeRegistered = callbackScheme.map { registeredSchemes.contains($0.lowercased()) } ?? false
        if let callbackScheme, !callbackSchemeRegistered {
            debugLog("[Auth] callback scheme not registered:", callbackScheme, "registered:", Array(registeredSchemes).sorted())
        }

        let oauthStartURLs: [ExternalAuthProvider: URL] = [
            .google: runtimeConfig.googleOAuthStartURL,
            .x: runtimeConfig.xOAuthStartURL
        ].compactMapValues { $0 }
        let tokenBroker: ExternalAuthTokenBroker? = {
            guard let callbackScheme,
                  callbackSchemeRegistered,
                  !oauthStartURLs.isEmpty else {
                return nil
            }
            return OAuthWebAuthTokenBroker(
                startURLs: oauthStartURLs,
                callbackScheme: callbackScheme
            )
        }()

        let allowManualTokenInput: Bool = {
#if DEBUG
            return runtimeConfig.allowsManualTokenInput
#else
            return false
#endif
        }()

        var verifiers: [any ExternalAuthTokenVerifier] = []
        if let endpoint = runtimeConfig.verificationEndpointURL {
            verifiers.append(
                BackendAuthAPITokenVerifier(
                    configuration: .init(
                        endpoint: endpoint,
                        bearerToken: runtimeConfig.verificationBearerToken,
                        timeoutSeconds: runtimeConfig.verificationTimeoutSeconds
                    )
                )
            )
        } else {
            verifiers.append(BackendPendingAuthTokenVerifier())
        }
        let allowDevelopmentVerifier: Bool = {
#if DEBUG
            return true
#else
            return false
#endif
        }()
        if allowDevelopmentVerifier {
            verifiers.append(DevelopmentExternalAuthTokenVerifier())
        }

        let verifier = CompositeExternalAuthTokenVerifier(verifiers: verifiers)
        return ProfileViewModel(
            get: getMyProfile,
            update: updateMyProfile,
            authTokenVerifier: verifier,
            termsOfServiceURL: runtimeConfig.termsOfServiceURL,
            privacyPolicyURL: runtimeConfig.privacyPolicyURL,
            defaultSecurityLogRetentionDays: runtimeConfig.defaultSecurityLogRetentionDays,
            maxSecurityLogRetentionDays: runtimeConfig.maxSecurityLogRetentionDays,
            isServerAuthVerificationConfigured: runtimeConfig.verificationEndpointURL != nil,
            serverAuthEndpointHost: runtimeConfig.verificationEndpointURL?.host,
            isDevelopmentVerifierEnabled: allowDevelopmentVerifier,
            externalAuthTokenBroker: tokenBroker,
            oauthConfiguredProviders: Set(oauthStartURLs.keys),
            oauthCallbackScheme: callbackScheme,
            isOAuthCallbackSchemeRegistered: callbackSchemeRegistered,
            allowsManualExternalAuthTokenInput: allowManualTokenInput,
            isLoginBypassEnabled: Self.boolEnv("UITEST_BYPASS_LOGIN"),
            appDefaults: appGroupDefaults
        )
    }

    private func makeAuthRepository(runtimeConfig: ExternalAuthRuntimeConfiguration) -> AuthRepository {
        LocalAuthRepository(
            defaults: appGroupDefaults,
            profileRepository: profileRepo,
            configuration: .init(
                signInWithAppleEnabled: launchConfiguration.signInWithAppleEnabled,
                googleOAuthEnabled: launchConfiguration.googleSignInEnabled
                    && runtimeConfig.googleOAuthStartURL != nil,
                guestModeEnabled: launchConfiguration.guestModeEnabled,
                adminMenuEnabled: launchConfiguration.adminMenuEnabled,
                adminAppleUserIDs: runtimeConfig.adminAppleUserIDs,
                adminEmails: runtimeConfig.adminEmails
            )
        )
    }

    func makeNotificationScheduler() -> AppNotificationScheduler {
        AppNotificationScheduler(defaults: appGroupDefaults)
    }

    // MARK: - IAP

    func makeIAPStore() -> IAPStore {
        IAPStore(
            appGroupID: appGroupID,
            updateMyProfile: updateMyProfile
        )
    }

    // MARK: - Debug

    private func debugLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }

    private static func debugLaunchLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }

    private static func migrateLegacyAppGroupDataIfNeeded(
        preferredGroupID: String,
        legacyGroupIDs: [String]
    ) {
        let markerKey = "MyDailyPhrase.appGroupMigration.v2"
        guard let target = UserDefaults(suiteName: preferredGroupID) else { return }
        if target.bool(forKey: markerKey) { return }

        let targetHasAppData = target.dictionaryRepresentation().keys.contains { $0.hasPrefix("MyDailyPhrase.") }
        if targetHasAppData {
            target.set(true, forKey: markerKey)
            return
        }

        var copiedKeys = 0

        func copyAppKeys(from source: UserDefaults) {
            let sourcePairs = source.dictionaryRepresentation().filter { $0.key.hasPrefix("MyDailyPhrase.") }
            for (key, value) in sourcePairs where target.object(forKey: key) == nil {
                target.set(value, forKey: key)
                copiedKeys += 1
            }
        }

        for legacyID in legacyGroupIDs where legacyID != preferredGroupID {
            if let legacy = UserDefaults(suiteName: legacyID) {
                copyAppKeys(from: legacy)
            }
        }

        // AppGroup の取得に失敗していた環境向けに standard からも救済する
        copyAppKeys(from: .standard)

        target.set(true, forKey: markerKey)
        if copiedKeys > 0 {
            target.synchronize()
        }

        #if DEBUG
        print("[AppContainer] AppGroup migration copied keys:", copiedKeys, "->", preferredGroupID)
        #endif
    }

    private static func boolEnv(_ key: String) -> Bool {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return value == "1" || value == "true" || value == "yes"
    }

    private static func stringEnv(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    #if DEBUG
    private static func seedNotificationABMetricsForUITestIfNeeded(defaults: UserDefaults) {
        guard boolEnv("UITEST_SEED_NOTIFICATION_AB_METRICS") else { return }

        let readyGlobal = AppNotificationSettings.NotificationCampaignStats(
            a: .init(sent: 38, opened: 20, returned: 12),
            b: .init(sent: 36, opened: 16, returned: 10)
        )
        let readyByContext: [String: AppNotificationSettings.NotificationCampaignStats] = [
            "w2_morning": .init(
                a: .init(sent: 10, opened: 6, returned: 4),
                b: .init(sent: 8, opened: 3, returned: 2)
            ),
            "w4_evening": .init(
                a: .init(sent: 8, opened: 5, returned: 3),
                b: .init(sent: 9, opened: 4, returned: 2)
            ),
            "w6_night": .init(
                a: .init(sent: 7, opened: 3, returned: 2),
                b: .init(sent: 8, opened: 5, returned: 4)
            )
        ]
        AppNotificationSettings.saveCampaignStats(readyGlobal, for: .seasonMilestoneReady, to: defaults)
        AppNotificationSettings.saveCampaignContextStats(readyByContext, for: .seasonMilestoneReady, to: defaults)

        let reminderGlobal = AppNotificationSettings.NotificationCampaignStats(
            a: .init(sent: 44, opened: 20, returned: 11),
            b: .init(sent: 43, opened: 24, returned: 15)
        )
        let reminderByContext: [String: AppNotificationSettings.NotificationCampaignStats] = [
            "w1_slot_earlyEvening": .init(
                a: .init(sent: 8, opened: 3, returned: 2),
                b: .init(sent: 9, opened: 5, returned: 3)
            ),
            "w3_slot_primeTime": .init(
                a: .init(sent: 9, opened: 5, returned: 3),
                b: .init(sent: 8, opened: 6, returned: 4)
            ),
            "w5_slot_lateNight": .init(
                a: .init(sent: 7, opened: 3, returned: 1),
                b: .init(sent: 8, opened: 5, returned: 3)
            )
        ]
        AppNotificationSettings.saveCampaignStats(reminderGlobal, for: .seasonMilestoneReminder, to: defaults)
        AppNotificationSettings.saveCampaignContextStats(reminderByContext, for: .seasonMilestoneReminder, to: defaults)

        let timingGlobal = AppNotificationSettings.NotificationTimingStats(
            earlyEvening: .init(sent: 31, opened: 12, returned: 6),
            primeTime: .init(sent: 34, opened: 18, returned: 11),
            lateNight: .init(sent: 29, opened: 10, returned: 5)
        )
        let timingByWeekday: [String: AppNotificationSettings.NotificationTimingStats] = [
            "2": .init(
                earlyEvening: .init(sent: 8, opened: 2, returned: 1),
                primeTime: .init(sent: 9, opened: 5, returned: 3),
                lateNight: .init(sent: 7, opened: 2, returned: 1)
            ),
            "4": .init(
                earlyEvening: .init(sent: 7, opened: 3, returned: 2),
                primeTime: .init(sent: 8, opened: 4, returned: 3),
                lateNight: .init(sent: 6, opened: 2, returned: 1)
            ),
            "6": .init(
                earlyEvening: .init(sent: 9, opened: 3, returned: 2),
                primeTime: .init(sent: 10, opened: 6, returned: 4),
                lateNight: .init(sent: 8, opened: 3, returned: 2)
            )
        ]
        AppNotificationSettings.saveReminderTimingStats(timingGlobal, to: defaults)
        AppNotificationSettings.saveReminderTimingStatsByWeekday(timingByWeekday, to: defaults)

        let readyWinner = AppNotificationSettings.recommendedVariant(for: readyGlobal)
        let reminderWinner = AppNotificationSettings.recommendedVariant(for: reminderGlobal)
        defaults.set(readyWinner.rawValue, forKey: AppNotificationSettings.seasonMilestoneReadyCopyVariantKey)
        defaults.set(reminderWinner.rawValue, forKey: AppNotificationSettings.seasonMilestoneReminderCopyVariantKey)
        NotificationCenter.default.post(name: .notificationABMetricsDidUpdate, object: nil)
    }

    private static func seedLinkedAuthForUITestIfNeeded(
        get: GetMyProfileUseCase,
        update: UpdateMyProfileUseCase
    ) {
        guard boolEnv("UITEST_SEED_LINKED_AUTH") else { return }

        let providerRaw = stringEnv("UITEST_SEED_LINKED_AUTH_PROVIDER")?.lowercased()
            ?? LinkedAuthProvider.google.rawValue
        let provider = LinkedAuthProvider(rawValue: providerRaw) ?? .google
        let subject = stringEnv("UITEST_SEED_LINKED_AUTH_SUBJECT") ?? "uitest-linked-subject"
        let shouldSeedOnboardingPending = boolEnv("UITEST_SEED_ONBOARDING_PENDING")

        let current = get()
        if current.linkedAuthProvider != nil, current.linkedAuthUserId != nil {
            return
        }

        _ = update(
            linkedAuthProvider: provider.rawValue,
            linkedAuthUserId: subject,
            linkedAuthAt: Date(),
            hasCompletedOnboarding: !shouldSeedOnboardingPending,
            onboardingCompletedAt: shouldSeedOnboardingPending ? nil : Date(),
            onboardingVersion: shouldSeedOnboardingPending ? 0 : 1
        )
    }
    #endif

    private static func resetAppDataIfNeeded(preferredGroupID: String) {
        guard boolEnv("UITEST_RESET_APP_DATA") else { return }

        let migrationMarker = "MyDailyPhrase.appGroupMigration.v2"
        let targets: [UserDefaults] = [UserDefaults(suiteName: preferredGroupID), .standard]
            .compactMap { $0 }

        for defaults in targets {
            let keys = defaults.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("MyDailyPhrase.") || $0 == migrationMarker }
            for key in keys {
                defaults.removeObject(forKey: key)
            }
            defaults.synchronize()
        }
    }

    private func loadStringSet(forKey key: String) -> Set<String> {
        let values = appGroupDefaults.stringArray(forKey: key) ?? []
        return Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private func saveStringSet(_ values: Set<String>, forKey key: String) {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        appGroupDefaults.set(normalized, forKey: key)
    }
}

private extension Bundle {
    var registeredURLSchemes: Set<String> {
        guard let urlTypes = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return []
        }
        var schemes: Set<String> = []
        for item in urlTypes {
            let rawSchemes = item["CFBundleURLSchemes"] as? [String] ?? []
            for raw in rawSchemes {
                let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !normalized.isEmpty {
                    schemes.insert(normalized)
                }
            }
        }
        return schemes
    }
}
