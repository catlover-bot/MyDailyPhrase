import Foundation
import Domain

public final class LocalAuthRepository: AuthRepository, @unchecked Sendable {
    public struct Configuration: Sendable {
        public var googleOAuthEnabled: Bool
        public var guestModeEnabled: Bool
        public var adminAppleUserIDs: Set<String>
        public var adminEmails: Set<String>

        public init(
            googleOAuthEnabled: Bool = false,
            guestModeEnabled: Bool = true,
            adminAppleUserIDs: Set<String> = [],
            adminEmails: Set<String> = []
        ) {
            self.googleOAuthEnabled = googleOAuthEnabled
            self.guestModeEnabled = guestModeEnabled
            self.adminAppleUserIDs = Self.normalizedValues(adminAppleUserIDs)
            self.adminEmails = Self.normalizedValues(adminEmails)
        }

        private static func normalizedValues(_ values: Set<String>) -> Set<String> {
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        }
    }

    private struct StoredSession: Codable, Equatable {
        let provider: AuthProvider
        let providerUserID: String?
        let email: String?
        let startedAt: Date
    }

    private let defaults: UserDefaults
    private let profileRepository: UserProfileRepository
    private let configuration: Configuration
    private let makeUserID: @Sendable () -> String
    private let lock = NSRecursiveLock()
    private let sessionKey = "MyDailyPhrase.auth.session.v1"

    public init(
        defaults: UserDefaults,
        profileRepository: UserProfileRepository,
        configuration: Configuration = .init(),
        makeUserID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.defaults = defaults
        self.profileRepository = profileRepository
        self.configuration = configuration
        self.makeUserID = makeUserID
    }

    public var supportedProviders: Set<AuthProvider> {
        var providers: Set<AuthProvider> = [.signInWithApple]
        if configuration.googleOAuthEnabled {
            providers.insert(.google)
        }
        if configuration.guestModeEnabled {
            providers.insert(.guest)
        }
        return providers
    }

    public var currentSession: AuthSession? {
        refreshSession()
    }

    public func signInWithApple(
        userID: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) throws -> AuthSession {
        let trimmedUserID = normalizedUserIdentifier(userID)
        guard !trimmedUserID.isEmpty else {
            throw AuthError.invalidCredential
        }

        let normalizedEmail = normalizedEmailValue(email)
        let updatedProfile = profileRepository.mutateMyProfile(
            { profile in
                profile.linkedAuthProvider = LinkedAuthProvider.apple.rawValue
                profile.linkedAuthUserId = trimmedUserID
                profile.linkedAuthAt = Date()
                let proposedName = suggestedDisplayName(
                    current: profile.displayName,
                    fallback: [familyName, givenName]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined()
                )
                if let proposedName {
                    profile.displayName = proposedName
                }
                profile.normalize()
            },
            makeIfMissing: { UserProfile(userId: self.makeUserID(), displayName: "Me") }
        )

        let stored = StoredSession(
            provider: .signInWithApple,
            providerUserID: trimmedUserID,
            email: normalizedEmail,
            startedAt: Date()
        )
        saveStoredSession(stored)
        return makeSession(from: stored, profile: updatedProfile)
    }

    public func signInWithGoogle(
        subject: String,
        email: String?,
        displayName: String?
    ) throws -> AuthSession {
        guard configuration.googleOAuthEnabled else {
            throw AuthError.providerNotConfigured(.google)
        }

        let trimmedSubject = normalizedUserIdentifier(subject)
        guard !trimmedSubject.isEmpty else {
            throw AuthError.invalidCredential
        }

        let normalizedEmail = normalizedEmailValue(email)
        let updatedProfile = profileRepository.mutateMyProfile(
            { profile in
                profile.linkedAuthProvider = LinkedAuthProvider.google.rawValue
                profile.linkedAuthUserId = trimmedSubject
                profile.linkedAuthAt = Date()
                let proposedName = suggestedDisplayName(current: profile.displayName, fallback: displayName)
                if let proposedName {
                    profile.displayName = proposedName
                }
                profile.normalize()
            },
            makeIfMissing: { UserProfile(userId: self.makeUserID(), displayName: "Me") }
        )

        let stored = StoredSession(
            provider: .google,
            providerUserID: trimmedSubject,
            email: normalizedEmail,
            startedAt: Date()
        )
        saveStoredSession(stored)
        return makeSession(from: stored, profile: updatedProfile)
    }

    public func signInAsGuest(displayName: String?) -> AuthSession {
        let updatedProfile = profileRepository.mutateMyProfile(
            { profile in
                if let displayName = suggestedDisplayName(current: profile.displayName, fallback: displayName) {
                    profile.displayName = displayName
                }
                profile.normalize()
            },
            makeIfMissing: { UserProfile(userId: self.makeUserID(), displayName: "Me") }
        )

        let stored = StoredSession(
            provider: .guest,
            providerUserID: nil,
            email: nil,
            startedAt: Date()
        )
        saveStoredSession(stored)
        return makeSession(from: stored, profile: updatedProfile)
    }

    public func signOut() {
        withLock {
            defaults.removeObject(forKey: sessionKey)
        }
    }

    public func refreshSession() -> AuthSession? {
        withLock {
            let profile = currentProfile()

            if let stored = loadStoredSession() {
                return makeSession(from: stored, profile: profile)
            }

            guard let provider = AuthProvider.fromLinkedAuthProvider(profile.linkedAuthProvider),
                  let providerUserID = normalizedOptional(profile.linkedAuthUserId) else {
                return nil
            }

            let restored = StoredSession(
                provider: provider,
                providerUserID: providerUserID,
                email: nil,
                startedAt: profile.linkedAuthAt ?? Date()
            )
            saveStoredSession(restored)
            return makeSession(from: restored, profile: profile)
        }
    }

    public func requestAccountDeletion() throws {
        throw AuthError.accountDeletionUnavailable
    }

    public func isAdmin(session: AuthSession?) -> Bool {
        guard let session else { return false }
        return session.isAdmin
    }

    public func adminCapabilities(session: AuthSession?) -> Set<AdminCapability> {
        guard let session else { return [] }
        return Set(session.adminCapabilities)
    }

    private func loadStoredSession() -> StoredSession? {
        guard let data = defaults.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    private func saveStoredSession(_ session: StoredSession) {
        withLock {
            if let data = try? JSONEncoder().encode(session) {
                defaults.set(data, forKey: sessionKey)
            }
        }
    }

    private func makeSession(from stored: StoredSession, profile: UserProfile) -> AuthSession {
        let adminCaps = resolvedAdminCapabilities(provider: stored.provider, providerUserID: stored.providerUserID, email: stored.email)
        let isAdmin = !adminCaps.isEmpty
        var roles: [UserRole] = [.user]
        if isAdmin {
            roles.append(.admin)
        }

        let user = AuthUser(
            id: profile.userId,
            providerUserID: stored.providerUserID,
            displayName: profile.displayName,
            email: stored.email,
            provider: stored.provider
        )

        return AuthSession(
            user: user,
            roles: roles,
            adminCapabilities: Array(adminCaps),
            startedAt: stored.startedAt,
            refreshedAt: Date(),
            requiresProfileSetup: requiresProfileSetup(profile.displayName, provider: stored.provider)
        )
    }

    private func resolvedAdminCapabilities(
        provider: AuthProvider,
        providerUserID: String?,
        email: String?
    ) -> Set<AdminCapability> {
        guard provider != .guest else { return [] }

        let normalizedEmail = normalizedEmailValue(email)
        let normalizedProviderUserID = normalizedOptional(providerUserID)?.lowercased()

        let matchesAppleAllowlist = provider == .signInWithApple
            && normalizedProviderUserID.map { configuration.adminAppleUserIDs.contains($0) } == true
        let matchesEmailAllowlist = normalizedEmail.map { configuration.adminEmails.contains($0) } == true

        return matchesAppleAllowlist || matchesEmailAllowlist
            ? AdminCapability.fullAdminSet
            : []
    }

    private func requiresProfileSetup(_ displayName: String, provider: AuthProvider) -> Bool {
        guard provider != .guest else { return false }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Me"
    }

    private func suggestedDisplayName(current: String, fallback: String?) -> String? {
        let currentTrimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentTrimmed.isEmpty, currentTrimmed != "Me" {
            return nil
        }

        let proposed = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !proposed.isEmpty else { return nil }
        return proposed
    }

    private func currentProfile() -> UserProfile {
        if let profile = profileRepository.getMyProfile() {
            return profile
        }
        let profile = makeProfile()
        profileRepository.saveMyProfile(profile)
        return profile
    }

    private func makeProfile() -> UserProfile {
        UserProfile(userId: makeUserID(), displayName: "Me")
    }

    private func normalizedUserIdentifier(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedEmailValue(_ raw: String?) -> String? {
        normalizedOptional(raw)?.lowercased()
    }

    private func normalizedOptional(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
