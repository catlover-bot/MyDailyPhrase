import SwiftUI
import AuthenticationServices
import Domain

struct ManualAuthPreviewSheet: View {
    private enum PreviewMode: String, CaseIterable, Identifiable {
        case welcome = "Welcome"
        case login = "Login"
        case register = "Register"
        case setup = "Setup"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .welcome: return "ようこそ"
            case .login: return "ログイン"
            case .register: return "新しくはじめる"
            case .setup: return "アカウント設定"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AppAuthViewModel
    @State private var previewMode: PreviewMode = .welcome
    @State private var copyFeedback: String? = nil

    init(makeViewModel: @escaping () -> AppAuthViewModel) {
        _vm = StateObject(wrappedValue: makeViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeroCard(
                        eyebrow: "手動テスト",
                        title: "ログイン機能プレビュー",
                        subtitle: "この画面は設定から開いたときだけ認証ランタイムを作ります。アプリ起動時の安全モードには影響しません。",
                        accent: .blue
                    ) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                InfoBadge(title: vm.isAuthEnabled ? "Auth有効" : "Auth無効", systemImage: "lock.shield", tint: vm.isAuthEnabled ? .green : .orange)
                                InfoBadge(title: vm.canUseAppleSignIn ? "Apple有効" : "Apple準備中", systemImage: "apple.logo", tint: .black)
                                InfoBadge(title: vm.canUseGuestMode ? "ゲスト可" : "ゲスト不可", systemImage: "person", tint: .teal)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                InfoBadge(title: vm.isAuthEnabled ? "Auth有効" : "Auth無効", systemImage: "lock.shield", tint: vm.isAuthEnabled ? .green : .orange)
                                InfoBadge(title: vm.canUseAppleSignIn ? "Apple有効" : "Apple準備中", systemImage: "apple.logo", tint: .black)
                                InfoBadge(title: vm.canUseGuestMode ? "ゲスト可" : "ゲスト不可", systemImage: "person", tint: .teal)
                            }
                        }
                    }

                    Picker("表示", selection: $previewMode) {
                        ForEach(PreviewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let message = vm.inlineMessage {
                        AppSectionCard(title: "お知らせ") {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    previewContent
                    authDiagnosticsCard
                }
                .frame(maxWidth: AppChrome.standardPageMaxWidth)
                .padding(.horizontal, AppChrome.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, AppChrome.standardPageBottomPadding)
            }
            .background(AppScreenBackground())
            .navigationTitle("ログイン機能テスト")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .task {
                await vm.load()
            }
            .onChange(of: vm.currentAuthStateText) { _, newValue in
                if newValue == "needsProfileSetup" {
                    previewMode = .setup
                }
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch previewMode {
        case .welcome:
            AppSectionCard(
                title: "Welcome",
                subtitle: "初回表示で伝える内容をここで確認できます。"
            ) {
                guideRow("1日1つのお題に答えます", systemImage: "sun.max.fill")
                guideRow("日記の回答は自動で公開されません", systemImage: "lock.fill")
                guideRow("共有は自分で選んだ内容だけです", systemImage: "square.and.arrow.up")
                guideRow("DMは相互フォローのみです", systemImage: "message.badge.fill")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        modeButton(.login, systemImage: "person.crop.circle.badge.checkmark")
                        modeButton(.register, systemImage: "sparkles")
                    }

                    VStack(spacing: 10) {
                        modeButton(.login, systemImage: "person.crop.circle.badge.checkmark")
                        modeButton(.register, systemImage: "sparkles")
                    }
                }
            }

        case .login:
            credentialsCard(
                title: "ログイン",
                subtitle: "Appleログインが有効な環境ではここから実際の認証を試せます。"
            )

        case .register:
            credentialsCard(
                title: "新しくはじめる",
                subtitle: "新規登録側のコピーとボタン状態を確認できます。"
            )

        case .setup:
            AppSectionCard(
                title: "アカウント設定",
                subtitle: "ログイン後の表示名設定を確認します。"
            ) {
                TextField("表示名", text: $vm.pendingDisplayName)
                    .textFieldStyle(.roundedBorder)

                Text("日記の回答は自動で公開されません。共有するときも、自分で選んだ内容だけが使われます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    vm.completeAccountSetup()
                } label: {
                    Label("この名前ではじめる", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func credentialsCard(title: String, subtitle: String) -> some View {
        AppSectionCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                if vm.canUseAppleSignIn {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                } else {
                    disabledProviderRow(
                        title: "Appleログインは現在準備中です",
                        detail: "AUTH_SIGN_IN_WITH_APPLE_ENABLED が有効になるまで、ボタンは実行されません。",
                        systemImage: "apple.logo"
                    )
                }

                if vm.canUseGoogleSignIn {
                    Button {
                        vm.signInWithGoogle()
                    } label: {
                        Label("Googleで続ける", systemImage: "g.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    disabledProviderRow(
                        title: "Googleログインは設定準備後に有効になります",
                        detail: "Google 設定がない環境でもアプリはビルド・起動できます。",
                        systemImage: "g.circle"
                    )
                }

                if vm.canUseGuestMode {
                    Button {
                        vm.continueAsGuest()
                    } label: {
                        Label("ゲストで試す", systemImage: "person")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    previewMode = .welcome
                    vm.showWelcome()
                } label: {
                    Label("Welcome に戻る", systemImage: "chevron.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var authDiagnosticsCard: some View {
        AppSectionCard(
            title: "認証診断",
            subtitle: "Apple user identifier は AUTH_ADMIN_APPLE_USER_IDS に追加するときの確認用です。"
        ) {
            diagnosticRow(title: "authState", value: vm.currentAuthStateText)
            diagnosticRow(title: "provider", value: vm.currentSession?.user.provider.displayName ?? "なし")
            diagnosticRow(title: "AuthUser.id", value: vm.currentSession?.user.id ?? "なし")
            diagnosticRow(title: "Apple / Provider User ID", value: vm.currentSession?.user.providerUserID ?? "なし")
            diagnosticRow(title: "email", value: vm.currentSession?.user.email ?? "なし")
            diagnosticRow(title: "roles", value: vm.currentSession?.roles.map(\.label).joined(separator: " / ") ?? "なし")
            diagnosticRow(title: "isAdmin", value: vm.isAdmin ? "true" : "false")
            diagnosticRow(title: "adminCapabilities", value: vm.currentSession?.adminCapabilities.map(\.label).joined(separator: " / ") ?? "なし")
            diagnosticRow(title: "lastAuthError", value: vm.lastAuthErrorDescription ?? "なし")

            Button {
                UIPasteboard.general.string = vm.diagnosticsReportText
                copyFeedback = "認証診断をコピーしました"
            } label: {
                Label("認証診断をコピー", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let copyFeedback {
                Text(copyFeedback)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                vm.inlineMessage = "Apple認証情報の取得に失敗しました"
                return
            }
            vm.signInWithApple(
                userID: credential.user,
                email: credential.email,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName
            )
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                vm.inlineMessage = "Appleログインをキャンセルしました"
            } else {
                vm.inlineMessage = "Appleログインに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    private func modeButton(_ mode: PreviewMode, systemImage: String) -> some View {
        Button {
            previewMode = mode
            switch mode {
            case .welcome:
                vm.showWelcome()
            case .login:
                vm.showLogin()
            case .register:
                vm.showRegister()
            case .setup:
                break
            }
        } label: {
            Label(mode.title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(mode == .login ? Color.accentColor : nil)
    }

    private func guideRow(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func disabledProviderRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func diagnosticRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AuthPreviewUnavailableSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppSectionCard(
                title: "ログイン機能テストは利用できません",
                subtitle: "このビルドでは手動テスト用の認証ランタイムを作れません。"
            ) {
                Text("通常起動には影響しません。設定値を確認してから再度お試しください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(AppScreenBackground())
            .navigationTitle("ログイン機能テスト")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
