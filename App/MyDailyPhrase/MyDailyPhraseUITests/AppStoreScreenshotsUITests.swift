import XCTest

final class AppStoreScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectoryURL: URL?
    private let screenshotModeFilePath = "/tmp/MyDailyPhrase.screenshot_mode"

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_APP_DATA"] = "1"
        app.launchEnvironment["UITEST_BYPASS_LOGIN"] = "1"
        app.launchEnvironment["UITEST_FORCE_UNLIMITED_GACHA"] = "1"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH"] = "1"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_PROVIDER"] = "google"
        app.launchEnvironment["UITEST_SEED_LINKED_AUTH_SUBJECT"] = "screenshot-user"
        app.launchEnvironment["UITEST_SEED_NOTIFICATION_AB_METRICS"] = "1"

        let outputDirFromEnv = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let outputDirFromModeFile: String? = {
            guard let raw = try? String(contentsOfFile: screenshotModeFilePath, encoding: .utf8) else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        if let outputDir = outputDirFromEnv, !outputDir.isEmpty {
            let dirURL = URL(fileURLWithPath: outputDir, isDirectory: true)
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            outputDirectoryURL = dirURL
        } else if let outputDir = outputDirFromModeFile {
            let dirURL = URL(fileURLWithPath: outputDir, isDirectory: true)
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            outputDirectoryURL = dirURL
        }
    }

    func testCaptureAppStoreScreenshots() throws {
        if outputDirectoryURL == nil {
            throw XCTSkip("スクリーンショットモードではないためスキップ")
        }

        app.launch()
        XCTAssertTrue(waitForMainTabBar(timeout: 10), "タブバーが表示されません")

        capture(named: "01_home")

        openTab(labels: ["ガチャ"])
        XCTAssertTrue(app.buttons["gacha.draw.once"].waitForExistence(timeout: 8))
        capture(named: "02_gacha")

        openCommunityScreen()
        let communityShown =
            app.navigationBars["Community"].waitForExistence(timeout: 4)
            || app.navigationBars["つながり"].waitForExistence(timeout: 4)
        XCTAssertTrue(communityShown, "コミュニティ画面が表示されません")
        capture(named: "03_community")

        openProfileScreen()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))
        capture(named: "04_profile")
        scrollToProfileNotificationDashboard()
        capture(named: "05_profile_dashboard")
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

    private func openTab(labels: [String]) {
        for label in labels {
            let tab = app.tabBars.buttons[label]
            if tab.waitForExistence(timeout: 1.5) {
                tab.tap()
                return
            }
        }
        XCTFail("Tab not found: \(labels.joined(separator: ","))")
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

    private func openCommunityScreen() {
        let communityTabLabels = ["つながり", "Community"]
        for label in communityTabLabels {
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
                for communityLabel in communityTabLabels {
                    let rowButton = app.buttons[communityLabel]
                    if rowButton.waitForExistence(timeout: 2.0) {
                        rowButton.tap()
                        return
                    }

                    let rowText = app.staticTexts[communityLabel]
                    if rowText.waitForExistence(timeout: 1.0) {
                        rowText.tap()
                        return
                    }
                }
            }
        }

        XCTFail("コミュニティ画面に遷移できませんでした")
    }

    private func scrollToProfileNotificationDashboard() {
        let dashboard = app.staticTexts["profile.notifications.ab.title"]
        if dashboard.waitForExistence(timeout: 1.0) {
            return
        }

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            app.swipeUp()
            if dashboard.waitForExistence(timeout: 0.6) {
                return
            }
        }

        XCTFail("Profile通知ダッシュボードが見つかりませんでした")
    }

    private func capture(named name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))

        let screenshot = XCUIScreen.main.screenshot()
        let pngData = screenshot.pngRepresentation

        if let outputDirectoryURL {
            let fileURL = outputDirectoryURL.appendingPathComponent("\(name).png")
            try? pngData.write(to: fileURL, options: [.atomic])
        }

        let attachment = XCTAttachment(data: pngData, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
