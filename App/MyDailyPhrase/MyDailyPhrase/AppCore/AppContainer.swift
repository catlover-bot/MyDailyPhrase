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
    private let profileSyncDiagnosticsStore: SupabaseProfileSyncDiagnosticsStore
    private let backendConnectionDiagnosticsStore: SupabaseConnectionDiagnosticsStore
    private let supabaseAuthSessionStore: SupabaseAuthSessionStore
    private let socialSyncDiagnosticsStore: SupabaseSocialSyncDiagnosticsStore
    private let communitySyncDiagnosticsStore: SupabaseCommunitySyncDiagnosticsStore

    // ===== Core =====
    private let entryRepo: EntryRepository
    private let promptRepo: PromptRepository

    private let enrichEntry: EnrichEntryUseCase
    private let toggleFavorite: ToggleFavoriteUseCase

    // ===== Profile / Challenge / Reaction =====
    private let profileRepo: UserProfileRepository
    private let socialConnectionRepo: SocialConnectionRepository
    private let communityTemplateRepo: CommunityRepository
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
    let backendRuntimeConfiguration: BackendRuntimeConfiguration
    private lazy var authRuntimeConfiguration: ExternalAuthRuntimeConfiguration = ExternalAuthRuntimeConfiguration.load()

    var settingsBackendContext: SettingsBackendContext {
        backendRuntimeConfiguration.diagnostics(
            profileSyncDiagnostics: profileSyncDiagnosticsStore.load(),
            connectionDiagnostics: backendConnectionDiagnosticsStore.load(),
            authDiagnostics: supabaseAuthSessionStore.loadDiagnostics(),
            socialSyncDiagnostics: socialSyncDiagnosticsStore.load(),
            communitySyncDiagnostics: communitySyncDiagnosticsStore.load()
        )
    }

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
        self.backendRuntimeConfiguration = BackendRuntimeConfiguration.load()
        self.profileSyncDiagnosticsStore = SupabaseProfileSyncDiagnosticsStore(defaults: resolvedDefaults)
        self.backendConnectionDiagnosticsStore = SupabaseConnectionDiagnosticsStore(defaults: resolvedDefaults)
        self.supabaseAuthSessionStore = SupabaseAuthSessionStore(defaults: resolvedDefaults)
        self.socialSyncDiagnosticsStore = SupabaseSocialSyncDiagnosticsStore(defaults: resolvedDefaults)
        self.communitySyncDiagnosticsStore = SupabaseCommunitySyncDiagnosticsStore(defaults: resolvedDefaults)
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
        let localProfileRepo = AppGroupUserProfileRepository(appGroupID: appGroupID)
        let localSocialRepo = LocalSocialConnectionRepository {
            SocialSupport.demoProfiles()
        }
        let localCommunityRepo = AppGroupCommunityTemplateRepository(appGroupID: appGroupID)
        if backendRuntimeConfiguration.supabaseConfiguration.canUseSupabase {
            if backendConnectionDiagnosticsStore.load().status == .localFallback {
                backendConnectionDiagnosticsStore.record(status: .configured)
            }
            if profileSyncDiagnosticsStore.load().status == .localFallback {
                profileSyncDiagnosticsStore.record(status: .configured)
            }
            if socialSyncDiagnosticsStore.load().status == .localFallback {
                socialSyncDiagnosticsStore.record(status: .configured)
            }
            if communitySyncDiagnosticsStore.load().status == .localFallback {
                communitySyncDiagnosticsStore.record(status: .configured, membershipStatus: .configured)
            }
            if backendRuntimeConfiguration.supabaseConfiguration.canUseAppleAuthBridge {
                if supabaseAuthSessionStore.loadSession() == nil,
                   supabaseAuthSessionStore.loadDiagnostics().status == .disabled {
                    supabaseAuthSessionStore.record(status: .signedOut)
                }
            } else if supabaseAuthSessionStore.loadDiagnostics().status == .disabled {
                supabaseAuthSessionStore.record(status: .missingConfiguration, error: "Supabase Auth bridge is disabled or incomplete")
            }
            self.profileRepo = SupabaseProfileRepository(
                configuration: backendRuntimeConfiguration.supabaseConfiguration,
                fallback: localProfileRepo,
                diagnosticsStore: profileSyncDiagnosticsStore,
                authSessionProvider: { [supabaseAuthSessionStore] in
                    supabaseAuthSessionStore.loadSession()
                }
            )
            self.socialConnectionRepo = SupabaseSocialConnectionRepository(
                configuration: backendRuntimeConfiguration.supabaseConfiguration,
                fallback: localSocialRepo,
                diagnosticsStore: socialSyncDiagnosticsStore,
                authSessionProvider: { [supabaseAuthSessionStore] in
                    supabaseAuthSessionStore.loadSession()
                }
            )
            self.communityTemplateRepo = SupabaseCommunityRepository(
                configuration: backendRuntimeConfiguration.supabaseConfiguration,
                fallback: localCommunityRepo,
                diagnosticsStore: communitySyncDiagnosticsStore,
                authSessionProvider: { [supabaseAuthSessionStore] in
                    supabaseAuthSessionStore.loadSession()
                }
            )
        } else {
            backendConnectionDiagnosticsStore.record(status: .localFallback)
            profileSyncDiagnosticsStore.record(status: .localFallback)
            supabaseAuthSessionStore.record(status: .disabled)
            socialSyncDiagnosticsStore.record(status: .localFallback)
            communitySyncDiagnosticsStore.record(status: .localFallback, membershipStatus: .localFallback)
            self.profileRepo = localProfileRepo
            self.socialConnectionRepo = localSocialRepo
            self.communityTemplateRepo = localCommunityRepo
        }
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
            "auth=\(launchConfiguration.effectiveAuthEnabled)",
            "backend=\(settingsBackendContext.statusText)"
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
            safeModeEnabled: launchConfiguration.safeModeEnabled,
            rootAuthGateEnabled: launchConfiguration.rootAuthGateEnabled,
            manualAuthTestEntryEnabled: launchConfiguration.authTestEntryEnabled,
            manualAppleSignInEnabled: launchConfiguration.manualAppleSignInEnabled,
            termsOfServiceURL: runtimeConfig.termsOfServiceURL ?? AppLinks.termsOfService,
            privacyPolicyURL: runtimeConfig.privacyPolicyURL ?? AppLinks.privacyPolicy,
            loadPersistedAuthError: { [suiteName = appGroupID] in
                let defaults = UserDefaults(suiteName: suiteName) ?? .standard
                return defaults.string(forKey: LocalAuthRepository.lastDiagnosticsErrorKey)
            },
            clearSupabaseAuthSession: { [supabaseAuthSessionStore] in
                supabaseAuthSessionStore.clearSession()
            }
        )
    }

    func makeManualAuthTestViewModel() -> AppAuthViewModel {
        let runtimeConfig = authRuntimeConfiguration
        return AppAuthViewModel(
            authRepository: makeAuthRepository(
                runtimeConfig: runtimeConfig,
                signInWithAppleEnabled: launchConfiguration.manualAppleSignInEnabled,
                googleSignInEnabled: false,
                guestModeEnabled: launchConfiguration.guestModeEnabled,
                adminMenuEnabled: launchConfiguration.manualAdminMenuEnabled
            ),
            getMyProfile: getMyProfile,
            updateMyProfile: updateMyProfile,
            authEnabled: launchConfiguration.authTestEntryEnabled,
            signInWithAppleEnabled: launchConfiguration.manualAppleSignInEnabled,
            googleSignInEnabled: false,
            guestModeEnabled: launchConfiguration.guestModeEnabled,
            adminMenuEnabled: launchConfiguration.manualAdminMenuEnabled,
            safeModeEnabled: launchConfiguration.safeModeEnabled,
            rootAuthGateEnabled: launchConfiguration.rootAuthGateEnabled,
            manualAuthTestEntryEnabled: launchConfiguration.authTestEntryEnabled,
            manualAppleSignInEnabled: launchConfiguration.manualAppleSignInEnabled,
            termsOfServiceURL: runtimeConfig.termsOfServiceURL ?? AppLinks.termsOfService,
            privacyPolicyURL: runtimeConfig.privacyPolicyURL ?? AppLinks.privacyPolicy,
            loadPersistedAuthError: { [suiteName = appGroupID] in
                let defaults = UserDefaults(suiteName: suiteName) ?? .standard
                return defaults.string(forKey: LocalAuthRepository.lastDiagnosticsErrorKey)
            },
            bridgeAppleSignInToSupabase: { [weak self] identityToken, nonce in
                guard let self else {
                    return SupabaseAuthBridgeOutcome(
                        didCreateSession: false,
                        message: "Supabase Auth連携を開始できませんでした",
                        supabaseUserID: nil
                    )
                }
                return await self.bridgeAppleSignInToSupabase(identityToken: identityToken, nonce: nonce)
            },
            clearSupabaseAuthSession: { [supabaseAuthSessionStore] in
                supabaseAuthSessionStore.clearSession()
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
            creatorEntitlementService: CreatorEntitlementService(defaults: appGroupDefaults),
            socialConnectionRepository: socialConnectionRepo,
            communityRepository: communityTemplateRepo
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
        let profileRepository = profileRepo
        let syncDiagnosticsStore = profileSyncDiagnosticsStore
        let loadProfileSyncDiagnostics: @Sendable () -> ProfileSyncDiagnostics = {
            syncDiagnosticsStore.load()
        }
        let syncProfileToBackend: @Sendable (UserProfile) async -> ProfileSyncDiagnostics = { profile in
            guard let repository = profileRepository as? any ProfileRepository else {
                return syncDiagnosticsStore.load()
            }
            guard let owner = ProfileOwnerIdentity(profile: profile) else {
                return ProfileSyncDiagnostics(status: .skippedSignedOut)
            }
            do {
                _ = try await repository.upsertCurrentUserProfile(profile, owner: owner)
            } catch {
                // Repository records a safe diagnostic and keeps the local profile.
            }
            return repository.profileSyncDiagnostics()
        }

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
                appDefaults: appGroupDefaults,
                loadProfileSyncDiagnostics: loadProfileSyncDiagnostics,
                syncProfileToBackend: syncProfileToBackend
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
            appDefaults: appGroupDefaults,
            loadProfileSyncDiagnostics: loadProfileSyncDiagnostics,
            syncProfileToBackend: syncProfileToBackend
        )
    }

    func runBackendConnectionTest() async -> SettingsBackendContext {
        backendConnectionDiagnosticsStore.record(status: .connecting)
        let tester = SupabaseBackendConnectionTester(
            configuration: backendRuntimeConfiguration.supabaseConfiguration
        )
        let result = await tester.testProfilesTableRead()
        backendConnectionDiagnosticsStore.save(result.diagnostics)
        return settingsBackendContext
    }

    func bridgeAppleSignInToSupabase(identityToken: String?, nonce: String?) async -> SupabaseAuthBridgeOutcome {
        let configuration = backendRuntimeConfiguration.supabaseConfiguration
        guard configuration.canUseAppleAuthBridge else {
            let message = configuration.canUseSupabase
                ? "Supabase Auth連携は設定で無効です。"
                : "Supabase URLまたはpublishable keyが未設定です。"
            supabaseAuthSessionStore.record(
                status: configuration.canUseSupabase ? .disabled : .missingConfiguration,
                error: message
            )
            return SupabaseAuthBridgeOutcome(didCreateSession: false, message: message, supabaseUserID: nil)
        }

        guard let identityToken,
              !identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let message = "Apple identityTokenを取得できなかったため、Supabase Auth連携をスキップしました。"
            supabaseAuthSessionStore.record(status: .failed, error: message)
            return SupabaseAuthBridgeOutcome(didCreateSession: false, message: message, supabaseUserID: nil)
        }

        supabaseAuthSessionStore.record(status: .signingIn)
        let client = SupabaseAuthRESTClient(configuration: configuration)
        do {
            let session = try await client.signInWithAppleIdentityToken(
                idToken: identityToken,
                nonce: nonce
            )
            supabaseAuthSessionStore.saveSession(session)
            await syncProfileAfterSupabaseAuthIfPossible(supabaseUserID: session.userID)
            return SupabaseAuthBridgeOutcome(
                didCreateSession: true,
                message: "Supabase Auth連携が完了しました",
                supabaseUserID: session.userID
            )
        } catch {
            let message = Self.supabaseAuthGuidanceMessage(for: error)
            supabaseAuthSessionStore.record(status: .failed, error: message)
            return SupabaseAuthBridgeOutcome(didCreateSession: false, message: message, supabaseUserID: nil)
        }
    }

    private func syncProfileAfterSupabaseAuthIfPossible(supabaseUserID: String) async {
        guard let repository = profileRepo as? any ProfileRepository else { return }
        let profile = getMyProfile()
        guard let owner = ProfileOwnerIdentity(profile: profile),
              owner.provider == LinkedAuthProvider.apple.rawValue else {
            profileSyncDiagnosticsStore.record(
                status: .skippedSignedOut,
                error: "Appleログイン済みプロフィールが見つかりません",
                userID: supabaseUserID
            )
            return
        }

        do {
            _ = try await repository.upsertCurrentUserProfile(profile, owner: owner)
        } catch {
            let status: ProfileSyncStatus = (error as? SupabaseProfileError) == .supabaseAuthSessionMissing
                ? .skippedSupabaseAuthMissing
                : .failed
            profileSyncDiagnosticsStore.record(
                status: status,
                error: Self.backendGuidanceMessage(for: error),
                userID: supabaseUserID
            )
        }
    }

    func runProfileSyncTest() async -> SettingsBackendContext {
        guard let repository = profileRepo as? any ProfileRepository else {
            profileSyncDiagnosticsStore.record(status: .failed, error: "ProfileRepository がSupabase同期に未対応です")
            return settingsBackendContext
        }

        let profile = getMyProfile()
        guard let owner = ProfileOwnerIdentity(profile: profile),
              owner.provider == LinkedAuthProvider.apple.rawValue else {
            profileSyncDiagnosticsStore.record(
                status: .skippedSignedOut,
                error: "Sign in with Apple 連携済みユーザーで実行してください"
            )
            return settingsBackendContext
        }

        profileSyncDiagnosticsStore.record(status: .syncing, userID: owner.userID)
        do {
            let synced = try await repository.upsertCurrentUserProfile(profile, owner: owner)
            _ = try? await repository.fetchCurrentUserProfile(owner: owner)
            if synced.userId == profile.userId {
                profileSyncDiagnosticsStore.record(status: .synced, userID: owner.userID)
            }
        } catch {
            if (error as? SupabaseProfileError) == .supabaseAuthSessionMissing {
                profileSyncDiagnosticsStore.record(
                    status: .skippedSupabaseAuthMissing,
                    error: Self.backendGuidanceMessage(for: error),
                    userID: owner.userID
                )
                return settingsBackendContext
            }
            profileSyncDiagnosticsStore.record(
                status: .failed,
                error: Self.backendGuidanceMessage(for: error),
                userID: owner.userID
            )
        }
        return settingsBackendContext
    }

    func runCommunitySyncTest() async -> SettingsBackendContext {
        let profile = getMyProfile()
        guard profile.linkedAuthProvider == LinkedAuthProvider.apple.rawValue else {
            communitySyncDiagnosticsStore.record(
                status: .skippedSignedOut,
                membershipStatus: .skippedSignedOut,
                error: "Sign in with Apple 連携済みユーザーで実行してください"
            )
            return settingsBackendContext
        }

        communitySyncDiagnosticsStore.record(status: .syncing, membershipStatus: .syncing)
        do {
            _ = try await communityTemplateRepo.refreshRemoteCommunities(for: profile)
        } catch {
            communitySyncDiagnosticsStore.record(
                status: .failed,
                membershipStatus: .failed,
                error: Self.communityBackendGuidanceMessage(for: error)
            )
        }
        return settingsBackendContext
    }

    private static func backendGuidanceMessage(for error: Error) -> String {
        if case let SupabaseProfileError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 401, 403:
                return "HTTP \(statusCode): Supabase Auth セッションがない、または auth.uid() と user_id が一致していない可能性があります。Supabase Auth連携とRLS policyを確認してください。\(String(message.prefix(160)))"
            case 404:
                return "HTTP 404: profiles テーブルが見つかりません。schema.sql が適用済みか確認してください。\(String(message.prefix(160)))"
            default:
                return "HTTP \(statusCode): プロフィール同期に失敗しました。\(String(message.prefix(160)))"
            }
        }
        if case let SupabaseProfileError.unavailable(status) = error {
            return "Supabase が利用できません: \(status.label)"
        }
        if case SupabaseProfileError.supabaseAuthSessionMissing = error {
            return "ローカル保存済み / Supabase認証待ち"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private static func communityBackendGuidanceMessage(for error: Error) -> String {
        if case let SupabaseCommunityRepositoryError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 401, 403:
                return "HTTP \(statusCode): Community同期がRLSで拒否されました。Supabase Auth session と auth.uid() の一致、communities/memberships policy を確認してください。\(String(message.prefix(160)))"
            case 404:
                return "HTTP 404: communities または memberships テーブルが見つかりません。schema.sql が適用済みか確認してください。\(String(message.prefix(160)))"
            default:
                return "HTTP \(statusCode): Community同期に失敗しました。\(String(message.prefix(160)))"
            }
        }
        if case SupabaseCommunityRepositoryError.supabaseAuthSessionMissing = error {
            return "ローカル保存済み / Supabase認証待ち"
        }
        if case SupabaseCommunityRepositoryError.targetIsLocalOnly = error {
            return "ローカルコミュニティのためSupabase同期をスキップしました"
        }
        if case SupabaseCommunityRepositoryError.creationNotAllowed = error {
            return "コミュニティ作成権限がありません"
        }
        if case let SupabaseCommunityRepositoryError.unavailable(status) = error {
            return "Supabase が利用できません: \(status.label)"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private static func supabaseAuthGuidanceMessage(for error: Error) -> String {
        if case let SupabaseAuthBridgeError.invalidResponse(statusCode, message) = error {
            switch statusCode {
            case 400, 401, 403:
                return "HTTP \(statusCode): Supabase AuthでApple tokenを確認できませんでした。SupabaseのApple Provider設定、Service ID/Bundle ID、nonce設定を確認してください。\(String(message.prefix(140)))"
            default:
                return "HTTP \(statusCode): Supabase Auth連携に失敗しました。\(String(message.prefix(140)))"
            }
        }
        if case SupabaseAuthBridgeError.missingAppleIdentityToken = error {
            return "Apple identityTokenを取得できませんでした。Appleログインをもう一度試してください。"
        }
        if case SupabaseAuthBridgeError.missingConfiguration = error {
            return "Supabase URLまたはpublishable keyが未設定です。"
        }
        if case SupabaseAuthBridgeError.disabled = error {
            return "Supabase Auth連携は設定で無効です。"
        }
        return String(error.localizedDescription.prefix(180))
    }

    private func makeAuthRepository(
        runtimeConfig: ExternalAuthRuntimeConfiguration,
        signInWithAppleEnabled: Bool? = nil,
        googleSignInEnabled: Bool? = nil,
        guestModeEnabled: Bool? = nil,
        adminMenuEnabled: Bool? = nil
    ) -> AuthRepository {
        LocalAuthRepository(
            defaults: appGroupDefaults,
            profileRepository: profileRepo,
            configuration: .init(
                signInWithAppleEnabled: signInWithAppleEnabled ?? launchConfiguration.signInWithAppleEnabled,
                googleOAuthEnabled: (googleSignInEnabled ?? launchConfiguration.googleSignInEnabled)
                    && runtimeConfig.googleOAuthStartURL != nil,
                guestModeEnabled: guestModeEnabled ?? launchConfiguration.guestModeEnabled,
                adminMenuEnabled: adminMenuEnabled ?? launchConfiguration.adminMenuEnabled,
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
