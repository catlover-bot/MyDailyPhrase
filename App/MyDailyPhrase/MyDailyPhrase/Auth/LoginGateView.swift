import SwiftUI
import AuthenticationServices

struct LoginGateView: View {
    @ObservedObject var vm: AppAuthViewModel

    var body: some View {
        ZStack {
            AppScreenBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    authHero

                    if let message = vm.inlineMessage {
                        AppSectionCard(title: "お知らせ") {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    switch vm.entryScreen {
                    case .welcome:
                        welcomeScreen
                    case .login:
                        credentialsScreen(
                            title: "ログイン",
                            subtitle: "Appleでのログインを優先しながら、記録と見た目をこの端末にやさしくつなぎます。"
                        )
                    case .register:
                        credentialsScreen(
                            title: "新しくはじめる",
                            subtitle: "日記は非公開のまま始められます。あとから共有やコミュニティを選べます。"
                        )
                    case .setup:
                        accountSetupScreen
                    }

                    legalLinks
                }
                .frame(maxWidth: AppChrome.standardPageMaxWidth)
                .padding(.horizontal, AppChrome.screenHorizontalPadding)
                .padding(.top, AppChrome.standardPageTopPadding)
                .padding(.bottom, AppChrome.standardPageBottomPadding)
            }
        }
        .navigationBarHidden(true)
    }

    private var authHero: some View {
        PageHeroCard(
            eyebrow: "安心して始める",
            title: "MyDailyPhrase",
            subtitle: "1日1つのお題に答えて、必要なときだけ共有できます。ガチャの装飾は見た目だけに使われ、日記の回答は自動で公開されません。",
            accent: .cyan
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    InfoBadge(title: "Appleログイン優先", systemImage: "apple.logo", tint: .black)
                    InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                    InfoBadge(title: "DMは相互フォローのみ", systemImage: "lock.bubble", tint: .blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoBadge(title: "Appleログイン優先", systemImage: "apple.logo", tint: .black)
                    InfoBadge(title: "共有は明示操作のみ", systemImage: "square.and.arrow.up", tint: .indigo)
                    InfoBadge(title: "DMは相互フォローのみ", systemImage: "lock.bubble", tint: .blue)
                }
            }
        }
    }

    private var welcomeScreen: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppSectionCard(
                title: "このアプリでできること",
                subtitle: "使い始める前に、安心してほしいことだけを短くまとめました。"
            ) {
                guideRow("1日1つのお題に答えます", systemImage: "sun.max.fill")
                guideRow("日記の回答は自動で公開されません", systemImage: "lock.fill")
                guideRow("装飾アイテムはプロフィールや共有カードで使えます", systemImage: "sparkles")
                guideRow("コミュニティ参加は無料です", systemImage: "person.2.fill")
                guideRow("DMは相互フォローの相手とのみ利用できます", systemImage: "message.badge.fill")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        vm.showLogin()
                    } label: {
                        Label("ログイン", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.showRegister()
                    } label: {
                        Label("新しくはじめる", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(spacing: 10) {
                    Button {
                        vm.showLogin()
                    } label: {
                        Label("ログイン", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.showRegister()
                    } label: {
                        Label("新しくはじめる", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if vm.canUseGuestMode {
                AppSectionCard(
                    title: "まずは試してみる",
                    subtitle: "ゲストでも日記・ガチャ・見た目は試せます。DMや管理者機能は使えません。"
                ) {
                    Button {
                        vm.continueAsGuest()
                    } label: {
                        Label("ゲストで続ける", systemImage: "person")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func credentialsScreen(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            AppSectionCard(title: title, subtitle: subtitle) {
                VStack(alignment: .leading, spacing: 12) {
                    if vm.canUseAppleSignIn {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
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
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    } else {
                        Label("Appleログインは現在準備中です", systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        Label("Googleログインは設定準備後に有効になります", systemImage: "g.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if vm.canUseGuestMode {
                        Button {
                            vm.continueAsGuest()
                        } label: {
                            Label("ゲストで試す", systemImage: "person")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    } else if !vm.canUseAppleSignIn && !vm.canUseGoogleSignIn {
                        Text("認証導線は現在安全確認中です。安定版では既存のローカル体験からそのまま利用できます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            AppSectionCard(
                title: "ログインすると分かりやすくなること",
                subtitle: "見た目やつながりはあとから選べます。まずは日記を安心して続けられることを優先しています。"
            ) {
                guideRow("共有する内容は自分で選べます", systemImage: "hand.tap.fill")
                guideRow("コミュニティ参加は無料です", systemImage: "person.2")
                guideRow("装飾アイテムは見た目だけを変えます", systemImage: "paintbrush.pointed.fill")
                guideRow("DMは相互フォローの相手とのみ使えます", systemImage: "lock.bubble.fill")
            }

            Button {
                vm.showWelcome()
            } label: {
                Label("戻る", systemImage: "chevron.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var accountSetupScreen: some View {
        AppSectionCard(
            title: "アカウント設定",
            subtitle: "プロフィールや共有カードに表示する名前を決めると、あとから見返しやすくなります。"
        ) {
            TextField("表示名", text: $vm.pendingDisplayName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Text("日記の回答は自動で公開されません。共有するときも、自分で選んだ内容だけが使われます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button {
                        vm.completeAccountSetup()
                    } label: {
                        Label("この名前ではじめる", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.showWelcome()
                        vm.signOut()
                    } label: {
                        Label("やり直す", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(spacing: 10) {
                    Button {
                        vm.completeAccountSetup()
                    } label: {
                        Label("この名前ではじめる", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        vm.showWelcome()
                        vm.signOut()
                    } label: {
                        Label("やり直す", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let termsURL = vm.termsOfServiceURL {
                Link(destination: termsURL) {
                    Label("利用規約", systemImage: "doc.text")
                }
                .font(.caption)
            }

            if let privacyURL = vm.privacyPolicyURL {
                Link(destination: privacyURL) {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
                .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
    }

    private func guideRow(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }
}
