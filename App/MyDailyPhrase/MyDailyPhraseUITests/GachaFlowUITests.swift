import XCTest

final class GachaFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_APP_DATA"] = "1"
        app.launchEnvironment["UITEST_FORCE_UNLIMITED_GACHA"] = "1"
        app.launchEnvironment["UITEST_BYPASS_LOGIN"] = "1"
    }

    func testGachaSpamTapDoesNotFreeze() throws {
        launchApp()
        openGachaTab()

        let drawOnce = app.buttons["gacha.draw.once"]
        XCTAssertTrue(drawOnce.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            drawOnce.tap()
        }

        _ = waitForBusyTransition(timeout: 10)
        recoverFromErrorIfPresented()
        closeCinematicIfNeeded()

        XCTAssertTrue(waitUntilHittable(drawOnce, timeout: 15), "ガチャ操作が復帰しませんでした")
    }

    func testSkipMovesToResult() throws {
        launchApp()
        openGachaTab()

        let drawTen = app.buttons["gacha.draw.ten"]
        XCTAssertTrue(drawTen.waitForExistence(timeout: 5))
        drawTen.tap()

        let skip = app.buttons["gacha.cinematic.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "スキップボタンが表示されませんでした")
        skip.tap()

        let close = app.buttons["gacha.cinematic.result.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8), "結果画面に遷移しませんでした")
        close.tap()

        XCTAssertTrue(drawTen.waitForExistence(timeout: 5))
    }

    func testForcedFailureCanRecover() throws {
        app.launchEnvironment["UITEST_GACHA_FORCE_DRAW_ERROR_ONCE"] = "1"
        launchApp()
        openGachaTab()

        let drawOnce = app.buttons["gacha.draw.once"]
        XCTAssertTrue(drawOnce.waitForExistence(timeout: 5))
        drawOnce.tap()

        let errorAlert = app.alerts["ガチャエラー"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 8), "エラーアラートが表示されませんでした")

        let recover = errorAlert.buttons["再同期"]
        XCTAssertTrue(recover.exists)
        recover.tap()

        XCTAssertTrue(drawOnce.waitForExistence(timeout: 5))
        XCTAssertTrue(drawOnce.isHittable)
    }

    private func launchApp() {
        app.launch()
    }

    private func openGachaTab() {
        let gachaTab = app.tabBars.buttons["ガチャ"]
        XCTAssertTrue(gachaTab.waitForExistence(timeout: 6))
        gachaTab.tap()

        XCTAssertTrue(app.buttons["gacha.draw.once"].waitForExistence(timeout: 6))
    }

    private func waitForCinematicOrResult(timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let skip = app.buttons["gacha.cinematic.skip"]
        let close = app.buttons["gacha.cinematic.result.close"]
        while Date() < deadline {
            if skip.exists || close.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func waitForBusyTransition(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let drawOnce = app.buttons["gacha.draw.once"]
        while Date() < deadline {
            if waitForCinematicOrResult(timeout: 0.3) {
                return true
            }
            if app.alerts["ガチャエラー"].exists {
                return true
            }
            if drawOnce.exists && !drawOnce.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return false
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func recoverFromErrorIfPresented() {
        let errorAlert = app.alerts["ガチャエラー"]
        guard errorAlert.waitForExistence(timeout: 1.0) else { return }
        let recover = errorAlert.buttons["再同期"]
        if recover.exists {
            recover.tap()
            return
        }
        let close = errorAlert.buttons["閉じる"]
        if close.exists {
            close.tap()
        }
    }

    private func closeCinematicIfNeeded() {
        let skip = app.buttons["gacha.cinematic.skip"]
        if skip.waitForExistence(timeout: 2), skip.isHittable {
            skip.tap()
        }

        let closeResult = app.buttons["gacha.cinematic.result.close"]
        if closeResult.waitForExistence(timeout: 10), closeResult.isHittable {
            closeResult.tap()
            return
        }

        let close = app.buttons["gacha.cinematic.close"]
        if close.exists, close.isHittable {
            close.tap()
        }
    }
}
