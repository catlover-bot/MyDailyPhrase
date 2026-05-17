import SwiftUI
import Combine
import Domain
import Presentation

struct RootView: View {
    private let container: AppContainer
    private let homeVM: HomeViewModel
    private let historyVM: HistoryViewModel
    private let gachaVM: GachaViewModel
    private let profileVM: ProfileViewModel
    private let communityLiteVM: CommunityLiteViewModel
    private let settingsVM: SettingsViewModel
    private let iapStore: IAPStore

    @StateObject private var authVM: AppAuthViewModel
    @State private var currentDecorationId = "classic"
    @State private var hasBootstrappedSignedInExperience = false

    init(container: AppContainer = AppContainer()) {
        self.container = container
        self.homeVM = container.makeHomeViewModel()
        self.historyVM = container.makeHistoryViewModel()
        self.gachaVM = container.makeGachaViewModel()
        self.profileVM = container.makeProfileViewModel()
        self.communityLiteVM = container.makeCommunityLiteViewModel()
        self.settingsVM = container.makeSettingsViewModel()
        self.iapStore = container.makeIAPStore()
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
        .environmentObject(authVM)
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            homeVM.load()
            historyVM.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { _ in
            gachaVM.load()
            profileVM.load()
            communityLiteVM.load()
        }
        .onReceive(gachaVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
        .onReceive(profileVM.$selectedDecorationId) { selectedDecorationId in
            currentDecorationId = normalizedDecorationId(selectedDecorationId)
        }
        .onReceive(iapStore.$isCreatorPassActive.removeDuplicates()) { isActive in
            authVM.updateCreatorPassEntitlement(isActive)
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
        }
        .task {
            await authVM.load()
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
            await bootstrapSignedInExperienceIfNeeded()
        }
        .onChange(of: authVM.authState) { _, _ in
            communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
            Task {
                await bootstrapSignedInExperienceIfNeeded()
            }
        }
    }

    private func normalizedDecorationId(_ decorationId: String) -> String {
        let trimmed = decorationId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "classic" : trimmed
    }

    private var signedInShell: some View {
        ContentView(
            homeVM: homeVM,
            historyVM: historyVM,
            gachaVM: gachaVM,
            profileVM: profileVM,
            communityLiteVM: communityLiteVM,
            settingsVM: settingsVM
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

    private func bootstrapSignedInExperienceIfNeeded() async {
        if authVM.isSignedInOrGuest {
            if !hasBootstrappedSignedInExperience {
                homeVM.load()
                historyVM.load()
                gachaVM.load()
                profileVM.load()
                communityLiteVM.load()
                if FeatureFlags.paidGachaEnabled || FeatureFlags.creatorPassEnabled {
                    await iapStore.configure()
                    authVM.updateCreatorPassEntitlement(iapStore.isCreatorPassActive)
                }
                communityLiteVM.updateFeatureAccess(authVM.currentFeatureAccess)
                hasBootstrappedSignedInExperience = true
            }
        } else {
            hasBootstrappedSignedInExperience = false
        }
    }
}
