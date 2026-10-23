import XCTest
final class NavigationTests: XCTestCase {
    @MainActor func testNavigationAndScreenshots() throws {
        let app = XCUIApplication(); app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "YES", "-AppleLanguages", "(zh-Hans)"]; app.launch()
        XCTAssertTrue(app.navigationBars["工具箱"].waitForExistence(timeout: 10))
        capture("首页")
        app.buttons["打开图片工坊"].tap()
        XCTAssertTrue(app.navigationBars["图片工坊"].waitForExistence(timeout: 5))
        capture("图片工坊")
        app.tabBars.buttons["工具"].tap()
        XCTAssertTrue(app.navigationBars["全部工具"].waitForExistence(timeout: 5))
        capture("工具目录")
        app.staticTexts["铃声制作"].tap()
        XCTAssertTrue(app.navigationBars["铃声制作"].waitForExistence(timeout: 5))
        capture("铃声制作")
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        capture("设置")
    }
    @MainActor func testQRCodeGeneration() throws {
        let app = XCUIApplication(); app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "YES", "-AppleLanguages", "(zh-Hans)"]; app.launch()
        app.tabBars.buttons["工具"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("二维码")
        app.staticTexts["二维码"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["二维码"].waitForExistence(timeout: 5))
        let editor = app.textViews.firstMatch; editor.tap(); editor.typeText("ShunTools offline")
        app.buttons["生成二维码"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["处理完成"].waitForExistence(timeout: 10))
        capture("二维码结果")
    }
    @MainActor func testPhotoPickerWorkflow() throws {
        let app = XCUIApplication(); app.launchArguments = ["-appLanguage", "zh-Hans", "-welcomeCompleted", "YES", "-AppleLanguages", "(zh-Hans)"]; app.launch()
        app.buttons["打开图片工坊"].tap()
        app.buttons["从照片选择"].tap()
        let photo = app.images["PXGGridLayout-Info"].firstMatch
        guard photo.waitForExistence(timeout: 30) else { throw XCTSkip("请先给测试模拟器添加照片样本。") }
        photo.tap()
        let done = app.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "已选择 1 张")).firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<5 { if app.buttons["一键添加相机水印"].isHittable { break }; app.swipeUp() }
        app.buttons["一键添加相机水印"].tap()
        capture("相机水印设置")
        for _ in 0..<5 { if app.buttons["处理图片"].isHittable { break }; app.swipeUp() }
        app.buttons["处理图片"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["处理完成"].waitForExistence(timeout: 15))
        capture("图片处理结果")
        app.buttons["保存到文件"].tap()
        capture("系统文件导出")
    }
    @MainActor private func capture(_ name: String) { let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment) }
}
