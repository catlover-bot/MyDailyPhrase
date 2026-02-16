import XCTest

final class ProfileReleaseReadinessUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_APP_DATA"] = "1"
        app.launchEnvironment["UITEST_BYPASS_LOGIN"] = "1"
    }

    func testOAuthCallbackUnregisteredIsMissing() throws {
        app.launchEnvironment["UITEST_AUTH_OAUTH_CALLBACK_SCHEME_OVERRIDE"] = "ui-missing-callback"
        app.launch()

        openProfileScreen()

        let callbackStatus = app.staticTexts["profile.releaseReadiness.oauthCallback.status"]
        XCTAssertTrue(waitForElement(callbackStatus, timeout: 24), "Release Readiness の OAuth Callback status が見つかりません")
        XCTAssertEqual(callbackStatus.label, "Missing")

        let callbackDetail = app.staticTexts["profile.releaseReadiness.oauthCallback.detail"]
        XCTAssertTrue(waitForElement(callbackDetail, timeout: 12), "Release Readiness の OAuth Callback detail が見つかりません")
        XCTAssertTrue(callbackDetail.label.contains("ui-missing-callback"), "未登録scheme名が表示されていません")
        XCTAssertTrue(callbackDetail.label.contains("未登録"), "未登録メッセージが表示されていません")
    }

    func testNotificationDashboardShowsWeekdayAndTimingEvidence() throws {
        app.launchEnvironment["UITEST_SEED_NOTIFICATION_AB_METRICS"] = "1"
        app.launch()

        openProfileScreen()

        let dashboardTitle = app.staticTexts["profile.notifications.ab.title"]
        XCTAssertTrue(waitForElement(dashboardTitle, timeout: 10), "通知ダッシュボードが表示されません")

        let variantHeader = app.staticTexts["profile.notifications.ab.variantHeader.seasonMilestoneReady"]
        XCTAssertTrue(waitForElement(variantHeader, timeout: 8), "文言別実測ヘッダが見つかりません")

        let weekdayHeader = app.staticTexts["profile.notifications.ab.weekdayHeader.seasonMilestoneReady"]
        XCTAssertTrue(waitForElement(weekdayHeader, timeout: 8), "曜日別実測ヘッダが見つかりません")

        let timingHeader = app.staticTexts["profile.notifications.ab.timingHeader.seasonMilestoneReminder"]
        XCTAssertTrue(waitForElement(timingHeader, timeout: 8), "時間帯別実測ヘッダが見つかりません")

        let weekdayTimingHeader = app.staticTexts["profile.notifications.ab.weekdayTimingHeader.seasonMilestoneReminder"]
        XCTAssertTrue(waitForElement(weekdayTimingHeader, timeout: 8), "曜日×時間帯ヘッダが見つかりません")

        XCTAssertTrue(waitForElement(app.staticTexts["18:30"], timeout: 6), "18:30 スロットが見つかりません")
        XCTAssertTrue(waitForElement(app.staticTexts["20:30"], timeout: 6), "20:30 スロットが見つかりません")
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
                    if rowText.waitForExistence(timeout: 0.8) {
                        rowText.tap()
                        return
                    }
                }
            }
        }

        XCTFail("プロフィール画面に遷移できませんでした")
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
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
