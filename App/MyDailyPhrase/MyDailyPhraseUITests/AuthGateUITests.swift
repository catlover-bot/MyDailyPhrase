import XCTest

final class AuthGateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_APP_DATA"] = "1"
    }

    func testLoginGateAppearsWhenNoLinkedAuth() throws {
        app.launchEnvironment["UITEST_BYPASS_LOGIN"] = "0"
        app.launch()

        let appleLogin = app.buttons["auth.login.apple"]
        XCTAssertTrue(appleLogin.waitForExistence(timeout: 8), "未ログイン時にログインゲートが表示されません")
        XCTAssertTrue(app.buttons["auth.login.google"].exists)
        XCTAssertTrue(app.buttons["auth.login.x"].exists)
    }

    func testUnlinkReturnsToLoginGate() throws {
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH"] = "1"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_PROVIDER"] = "google"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_SUBJECT"] = "uitest-session-user"
        app.launch()

        XCTAssertTrue(waitForMainTabBar(timeout: 8), "連携済みセッションでメイン画面に入れません")

        openProfileScreen()

        let unlinkButton = app.buttons["profile.auth.unlink"]
        XCTAssertTrue(waitForElementByScrolling(unlinkButton, timeout: 10), "連携解除ボタンが見つかりません")
        unlinkButton.tap()

        let appleLogin = app.buttons["auth.login.apple"]
        XCTAssertTrue(appleLogin.waitForExistence(timeout: 6), "連携解除後にログインゲートへ戻りません")
    }

    private func waitForMainTabBar(timeout: TimeInterval) -> Bool {
        let candidates = ["今日", "ガチャ", "Home", "Gacha"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in candidates where app.tabBars.buttons[label].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func openProfileScreen() {
        let profileTabLabels = ["プロフィール", "Profile"]
        for label in profileTabLabels {
            let tab = app.tabBars.buttons[label]
            if tab.waitForExistence(timeout: 1.2) {
                tab.tap()
                return
            }
        }

        let moreTabLabels = ["More", "その他"]
        for label in moreTabLabels {
            let tab = app.tabBars.buttons[label]
            if tab.waitForExistence(timeout: 1.2) {
                tab.tap()
                for profileLabel in profileTabLabels {
                    let rowButton = app.buttons[profileLabel]
                    if rowButton.waitForExistence(timeout: 2.0) {
                        rowButton.tap()
                        return
                    }

                    let rowText = app.staticTexts[profileLabel]
                    if rowText.waitForExistence(timeout: 1.0) {
                        rowText.tap()
                        return
                    }
                }
            }
        }

        XCTFail("プロフィール画面に遷移できませんでした")
    }

    private func waitForElementByScrolling(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.waitForExistence(timeout: 1.0) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            app.swipeUp()
            if element.waitForExistence(timeout: 0.5) {
                return true
            }
        }
        return false
    }
}
