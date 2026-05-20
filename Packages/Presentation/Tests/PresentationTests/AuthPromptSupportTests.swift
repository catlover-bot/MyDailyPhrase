import Testing
@testable import Presentation

struct AuthPromptSupportTests {
    @Test("login CTA appears for guest or signed out social surfaces")
    func promptAppearsForGuestOrSignedOut() {
        let profilePrompt = AuthPromptSupport.prompt(
            for: .profile,
            isSignedIn: false,
            isGuest: false
        )
        let dmPrompt = AuthPromptSupport.prompt(
            for: .directMessage,
            isSignedIn: true,
            isGuest: true
        )

        #expect(profilePrompt?.primaryActionTitle == "ログイン / 新規登録")
        #expect(profilePrompt?.message.contains("日記は自動で公開されません") == true)
        #expect(dmPrompt?.title == "DMは相互フォローになると使えます")
        #expect(dmPrompt?.privacyNote.contains("共有する内容は自分で選べます") == true)
    }

    @Test("signed in non guest users do not need login prompt")
    func signedInUserHasNoPrompt() {
        let prompt = AuthPromptSupport.prompt(
            for: .follow,
            isSignedIn: true,
            isGuest: false
        )

        #expect(prompt == nil)
    }

    @Test("local linked account enables safe local social actions")
    func localLinkedAccountEnablesSocialActions() {
        #expect(AuthPromptSupport.canUseSocialActions(isAuthenticated: false, isGuest: false, hasLinkedAccount: true))
        #expect(AuthPromptSupport.canUseSocialActions(isAuthenticated: true, isGuest: false, hasLinkedAccount: false))
        #expect(AuthPromptSupport.canUseSocialActions(isAuthenticated: true, isGuest: true, hasLinkedAccount: false) == false)
        #expect(AuthPromptSupport.canUseSocialActions(isAuthenticated: false, isGuest: false, hasLinkedAccount: false) == false)
    }
}
