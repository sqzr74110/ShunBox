import XCTest
final class ExperienceTests: XCTestCase {
    @MainActor func testWelcomeDisclosesAdsAndAllowsFreeEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["欢迎使用顺匣"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "所有功能免费且无广告")).firstMatch.exists)
        let button = app.buttons["welcome.continue"]
        for _ in 0..<5 { if button.isHittable { break }; app.swipeUp() }
        capture("欢迎与广告说明")
        XCTAssertTrue(button.isHittable); button.tap()
        XCTAssertTrue(app.navigationBars["工具箱"].waitForExistence(timeout: 5))
    }
    @MainActor func testDeviceCheckNavigation() {
        let app = XCUIApplication(); app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "YES"]; app.launch()
        app.tabBars.buttons["工具"].tap()
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("设备")
        app.staticTexts["设备信息"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["硬件标识"].waitForExistence(timeout: 5)); capture("设备信息")
        app.swipeUp()
        app.buttons["设备自检"].firstMatch.tap()
        XCTAssertTrue(app.buttons["全屏纯色检查"].waitForExistence(timeout: 5))
        app.buttons["全屏纯色检查"].tap()
        XCTAssertTrue(app.buttons["下一种颜色"].waitForExistence(timeout: 5)); app.buttons["下一种颜色"].tap(); app.buttons["关闭"].tap()
        app.buttons["触控覆盖测试"].tap()
        XCTAssertTrue(app.buttons["重置"].waitForExistence(timeout: 5)); capture("触控测试")
    }
    @MainActor func testNineLanguageHomeScreens() {
        let names = [("zh-Hans","工具箱"),("zh-Hant","工具箱"),("en","Toolbox"),("ja","ツールボックス"),("ko","도구상자"),("fr","Boîte à outils"),("de","Werkzeugkasten"),("es","Caja de herramientas"),("pt-BR","Caixa de ferramentas")]
        for (code, title) in names {
            let app = XCUIApplication(); app.launchArguments = ["-appLanguage",code,"-welcomeCompleted","YES"]
            app.launch(); XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), code)
            capture("首页-" + code); app.terminate()
        }
    }
    @MainActor func testFollowSystemJapanese() {
        let app = XCUIApplication(); app.launchArguments = ["-appLanguage","system","-welcomeCompleted","YES","-AppleLanguages","(ja)"]
        app.launch(); XCTAssertTrue(app.navigationBars["ツールボックス"].waitForExistence(timeout: 10))
    }
    @MainActor func testChangeLanguageInSettingsAndDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages","(ja)","-welcomeCompleted","YES","-appearance","dark"]
        app.launch()
        app.buttons["設定"].firstMatch.tap()
        app.buttons["settings.language"].tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Open Image Studio"].waitForExistence(timeout: 5))
        capture("英文深色与语言切换")
    }
    @MainActor private func capture(_ name: String) { let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment) }
}
