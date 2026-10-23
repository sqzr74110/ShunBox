import XCTest
final class PreviewRegressionTests: XCTestCase {
    @MainActor func testFirstImageAndPDFPreviewCanCloseAndReopen() {
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "YES", "-uitest-media"]
        app.launch()
        sleep(3)
        app.tabBars.buttons["媒体库"].tap()
        let image = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "media.Preview-Test")).firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 10)); image.tap()
        let close = app.buttons["preview.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "glass-watermark-preview"; shot.lifetime = .keepAlways; add(shot)
        close.tap(); XCTAssertTrue(app.navigationBars["媒体库"].waitForExistence(timeout: 5))
        let pdf = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "media.", ".pdf")).firstMatch
        XCTAssertTrue(pdf.exists); pdf.tap(); XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        image.tap(); XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        app.buttons["设置"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["顺匣 · 你的随身工具箱"].waitForExistence(timeout: 5))
        let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); settings.name = "settings-refined"; settings.lifetime = .keepAlways; add(settings)
        app.tabBars.buttons["首页"].tap()
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); home.name = "home-refined"; home.lifetime = .keepAlways; add(home)
        app.terminate(); app.launchArguments.removeAll { $0 == "-uitest-media" }; app.launch()
        app.tabBars.buttons["媒体库"].tap(); XCTAssertTrue(image.waitForExistence(timeout: 5))
    }
}
