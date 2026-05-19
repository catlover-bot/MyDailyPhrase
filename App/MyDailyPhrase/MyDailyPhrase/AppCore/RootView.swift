import SwiftUI
import Combine
import Domain
import Presentation

struct RootView: View {
    private let container: AppContainer
    private let launchConfiguration: AppLaunchRuntimeConfiguration
    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let gachaVM: GachaViewModel
    private let profileVM: ProfileViewModel
    private let communityLiteVM: CommunityLiteViewModel
    private let settingsVM: SettingsViewModel
    private let iapStore: IAPStore

    @State private var currentDecorationId = "classic"

    init(container: AppContainer = AppContainer()) {
        self.container = container
        self.launchConfiguration = container.launchConfiguration
        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.gachaVM = container.makeGachaViewModel()
        self.profileVM = container.makeProfileViewModel()
        self.communityLiteVM = container.makeCommunityLiteViewModel()
        self.settingsVM = container.makeSettingsViewModel()
        self.iapStore = container.makeIAPStore()
        Self.debugLaunchLog(
            "[Launch] RootView init",
            "safeMode=\(launchConfiguration.safeModeEnabled)",
            "auth=\(launchConfiguration.effectiveAuthEnabled)"
        )
    }

    var body: some View {
        Group {
            if launchConfiguration.policy.shouldConstructAuthFlow {
                AuthenticatedLaunchRoot(
                    container: container,
                    launchConfiguration: launchConfiguration,
                    homeVM: homeVM,
                    historyVM: historyVM,
                    gachaVM: gachaVM,
                    profileVM: profileVM,
                    communityLiteVM: communityLiteVM,
                    settingsVM: settingsVM,
                    iapStore: iapStore,
                    currentDecorationId: currentDecorationId
                )
            } else {
                SafeModeLaunchRoot(
                    launchConfiguration: launchConfiguration,
                    homeVM: homeVM,
                    historyVM: historyVM,
                    gachaVM: gachaVM,
                    profileVM: profileVM,
                    communityLiteVM: communityLiteVM,
                    settingsVM: settingsVM,
                    iapStore: iapStore,
                    currentDecorationId: currentDecorationId
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            homeVM.load()
            historyVM.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            gachaVM.load()
            profileVM.load()
            if !launchConfiguration.safeModeEnabled {
                communityLiteVM.load()
            }
        }
        .onReceive(gachaVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
        .onReceive(profileVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
    }

    private func normalizedDecorationId(_ decorationId: String) -> String {
        let trimmed = decorationId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "classic" : trimmed
    }

    private static func debugLaunchLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }
}

private struct SafeModeLaunchRoot: View {
    let launchConfiguration: AppLaunchRuntimeConfiguration
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let gachaVM: GachaViewModel
    let profileVM: ProfileViewModel
    let communityLiteVM: CommunityLiteViewModel
    let settingsVM: SettingsViewModel
    let iapStore: IAPStore
    let currentDecorationId: String

    private var settingsAuthContext: SettingsAuthContext {
        .localSafeMode()
    }

    var body: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            gachaVM: gachaVM,
            profileVM: profileVM,
            communityLiteVM: communityLiteVM,
            settingsVM: settingsVM,
            settingsAuthContext: settingsAuthContext,
            onAuthSignOut: {},
            onAuthRequestDeletionSupport: {}
        )
        .environmentObject(iapStore)
        .environment(\.currentDecorationId, currentDecorationId)
        .task {
            communityLiteVM.updateFeatureAccess(.signedOutDefault)
            SafeModeLaunchRoot.debugLaunchLog(
                "[Launch] safe root displayed",
                "auth=\(launchConfiguration.effectiveAuthEnabled)",
                "safeMode=\(launchConfiguration.safeModeEnabled)"
            )
        }
    }

    private static func debugLaunchLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }
}

private struct AuthenticatedLaunchRoot: View {
    let container: AppContainer
    let launchConfiguration: AppLaunchRuntimeConfiguration
    let homeVM: HomeViewModel
    let historyVM: HistoryViewModel
    let gachaVM: GachaViewModel
    let profileVM: ProfileViewModel
    let communityLiteVM: CommunityLiteViewModel
    let settingsVM: SettingsViewModel
    let iapStore: IAPStore
    let currentDecorationId: String

    @StateObject private var authVM: AppAuthViewModel

    init(
        container: AppContainer,
        launchConfiguration: AppLaunchRuntimeConfiguration,
        homeVM: HomeViewModel,
        historyVM: HistoryViewModel,
        gachaVM: GachaViewModel,
        profileVM: ProfileViewModel,
        communityLiteVM: CommunityLiteViewModel,
        settingsVM: SettingsViewModel,
        iapStore: IAPStore,
        currentDecorationId: String
    ) {
        self.container = container
        self.launchConfiguration = launchConfiguration
        self.homeVM = homeVM
        self.historyVM = historyVM
        self.gachaVM = gachaVM
        self.profileVM = profileVM
        self.communityLiteVM = communityLiteVM
        self.settingsVM = settingsVM
        self.iapStore = iapStore
        self.currentDecorationId = currentDecorationId
        _authVM = StateObject(wrappedValue: container.makeAuthViewModel())
    }

    var body: some View {
        Group {
            switch authVM.authState {
            case .loading:
                authLoadingView
            case .signedOut, .needsProfileSetup(_), .failed(_):
                LoginGateView(vm: authVM)
            case .signedIn(_), .guest(_):
                signedInShell
            }
        }
        .task {
            await authVM.load()
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
            AuthenticatedLaunchRoot.debugLaunchLog("[Launch] authenticated root displayed")
        }
        .onChange(of: authVM.authState) { _, _ in
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
        }
        .onReceive(iapStore.$isCreatorPassActive.removeDuplicates()) { isActive in
            authVM.updateCreatorPassEntitlement(isActive)
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
        }
    }

    private var signedInShell: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            gachaVM: gachaVM,
            profileVM: profileVM,
            communityLiteVM: communityLiteVM,
            settingsVM: settingsVM,
            settingsAuthContext: SettingsAuthContext(authViewModel: authVM, safeModeEnabled: launchConfiguration.safeModeEnabled),
            onAuthSignOut: { authVM.signOut() },
            onAuthRequestDeletionSupport: { authVM.requestAccountDeletionSupport() }
        )
        .environmentObject(iapStore)
        .environment(\.currentDecorationId, currentDecorationId)
    }

    private var authLoadingView: some View {
        ZStack {
            AppScreenBackground()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("ログイン状態を確認しています")
                    .font(.headline)
                Text("日記の回答は自動で公開されず、共有は自分で選んだときだけ行われます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private static func debugLaunchLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }
}
