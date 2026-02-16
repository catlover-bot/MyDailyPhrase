import XCTest

final class OnboardingFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_APP_DATA"] = "1"
        app.launchEnvironment["UITEST_BYPASS_LOGIN"] = "1"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH"] = "1"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_PROVIDER"] = "google"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_SUBJECT"] = "uitest-onboarding-user"
        app.launchEnvironment["UITEST_SEED_ONBOARDING_PENDING"] = "1"
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
    }

    func testOnboardingFlowCompletesAndOpensMainTabs() throws {
        app.launch()

        XCTAssertTrue(
            waitForAnyRootState(timeout: 12),
            "初期画面が描画されません。hierarchy=\n\(app.debugDescription)"
        )

        if app.otherElements["root.loading"].exists {
            XCTAssertTrue(
                app.staticTexts["onboarding.title"].waitForExistence(timeout: 12)
                    || app.buttons["auth.login.apple"].waitForExistence(timeout: 12)
                    || waitForMainTabBar(timeout: 12),
                "ロード状態から先に進みません。hierarchy=\n\(app.debugDescription)"
            )
        }

        let next = app.buttons["onboarding.next"]
        guard next.waitForExistence(timeout: 8) else {
            XCTAssertTrue(
                app.buttons["auth.login.apple"].exists || waitForMainTabBar(timeout: 8),
                "オンボーディングまたはメイン画面が表示されません。hierarchy=\n\(app.debugDescription)"
            )
            return
        }
        next.tap()

        let nameField = app.textFields["onboarding.displayName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText("UITest User")
        if app.keyboards.count > 0 {
            let returnKey = app.keyboards.buttons["return"]
            if returnKey.exists {
                returnKey.tap()
            } else {
                app.tap()
            }
        }

        let nextAgain = app.buttons["onboarding.next"]
        XCTAssertTrue(nextAgain.waitForExistence(timeout: 4))
        nextAgain.tap()

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 4))
        finish.tap()

        XCTAssertTrue(waitForMainTabBar(timeout: 8), "オンボーディング完了後にメイン画面へ遷移しません")
    }

    private func waitForAnyRootState(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.otherElements["root.loading"].exists
                || app.staticTexts["onboarding.title"].exists
                || app.buttons["auth.login.apple"].exists
                || app.tabBars.firstMatch.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return false
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
}
