import SwiftUI
import AuthenticationServices

struct LoginGateView: View {
    @ObservedObject var vm: ProfileViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.08),
                    Color.cyan.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("MyDailyPhrase")
                            .font(.largeTitle.weight(.heavy))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("auth.login.title")
                        Text("ログインして、記録とつながりを同期")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                                    vm.lastMessage = "Apple認証情報の取得に失敗しました"
                                    return
                                }
                                vm.linkAppleAccount(appleUserID: credential.user, fullName: credential.fullName)
                            case .failure(let error):
                                vm.lastMessage = "Appleログインに失敗しました: \(error.localizedDescription)"
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                        .accessibilityIdentifier("auth.login.apple")

                        Button {
                            Task { await vm.linkGoogleAccountUsingServerToken() }
                        } label: {
                            Label(vm.isLinkingExternalAuth ? "Google連携中…" : "Googleでログイン", systemImage: "g.circle")
                                .compactActionLabel()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isLinkingExternalAuth || !vm.canLinkGoogleAccount)
                        .accessibilityIdentifier("auth.login.google")

                        Button {
                            Task { await vm.linkXAccountUsingServerToken() }
                        } label: {
                            Label(vm.isLinkingExternalAuth ? "X連携中…" : "Xでログイン", systemImage: "x.circle")
                                .compactActionLabel()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.isLinkingExternalAuth || !vm.canLinkXAccount)
                        .accessibilityIdentifier("auth.login.x")

                        if vm.canInputExternalAuthTokenManually {
                            SecureField("サーバー検証トークン（開発用）", text: $vm.externalAuthVerificationToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let message = vm.lastMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("auth.login.message")
                    }

                    Text(vm.externalAuthInputGuideText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .accessibilityIdentifier("auth.login.guide")

                    VStack(spacing: 6) {
                        if let termsURL = vm.termsOfServiceURL {
                            Link("利用規約", destination: termsURL)
                                .font(.caption2)
                        }
                        if let privacyURL = vm.privacyPolicyURL {
                            Link("プライバシーポリシー", destination: privacyURL)
                                .font(.caption2)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
        }
        .navigationBarHidden(true)
    }
}

private extension View {
    func compactActionLabel() -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }
}
