import XCTest
import AppIntents
import StoreKitTest
import StoreKit
import UIKit
@testable import ShunTools

final class IntegrationTests: XCTestCase {
    func testOutputNamesCannotEscapeTemporaryFolder() throws {
        for name in ["../outside.txt", "/tmp/outside.txt", "..", "a/b.png", "a\\b.png"] { XCTAssertThrowsError(try FileStore.destination(name)) }
        let file = try FileStore.destination("photo.png")
        XCTAssertTrue(file.path.hasPrefix(FileStore.root.path + "/"))
    }
    func testTrialBoundaryPurchaseAndMissingAdsNeverGateTools() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(604799), purchased: false, configured: true, lastAd: nil))
        XCTAssertTrue(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(604800), purchased: false, configured: true, lastAd: nil))
        XCTAssertFalse(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(900000), purchased: true, configured: true, lastAd: nil))
        XCTAssertFalse(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(900000), purchased: false, configured: false, lastAd: nil))
        XCTAssertFalse(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(900000), purchased: false, configured: true, lastAd: start.addingTimeInterval(899900)))
        XCTAssertFalse(AdEligibility.mayPresent(start: start, now: start.addingTimeInterval(-1), purchased: false, configured: true, lastAd: nil))
    }
    func testAllNineLanguageBundlesAndSafeInterpolation() throws {
        let previous = UserDefaults.standard.object(forKey: "appLanguage")
        defer { if let previous { UserDefaults.standard.set(previous, forKey: "appLanguage") } else { UserDefaults.standard.removeObject(forKey: "appLanguage") } }
        let homes = ["zh-Hans":"首页", "zh-Hant":"首頁", "en":"Home", "ja":"ホーム", "ko":"홈", "fr":"Accueil", "de":"Start", "es":"Inicio", "pt-BR":"Início"]
        for code in AppLanguage.supported {
            UserDefaults.standard.set(code, forKey: "appLanguage")
            XCTAssertEqual(L("首页"), homes[code], code)
            XCTAssertNotNil(Bundle.main.path(forResource: code, ofType: "lproj"), code)
            XCTAssertTrue(L("已覆盖 {0} / 60 格", "12").contains("12"), code)
            XCTAssertTrue(L("同步失败：{0}", "filename-{1}").contains("filename-{1}"), code)
        }
    }
    @MainActor func testShortcutsReturnUsableFilesAndRouteToTool() async throws {
        let qr = GenerateQRIntent(); qr.text = "https://example.com/shunbox"
        let qrResult = try await qr.perform()
        let qrFile = try XCTUnwrap(qrResult.value)
        let imageURL = try FileStore.destination("intent-qr.png"); try qrFile.data.write(to: imageURL)
        let decoded = try await QRProcessor.shared.recognize(imageURL)
        XCTAssertEqual(decoded, [qr.text])
        let convert = ConvertImageIntent(); convert.image = IntentFile(fileURL: imageURL, type: .png); convert.format = .jpeg
        let converted = try await convert.perform()
        let file = try XCTUnwrap(converted.value)
        XCTAssertNotNil(UIImage(data: file.data)); XCTAssertTrue(file.filename.hasSuffix(".jpg") || file.filename.hasSuffix(".jpeg"))
        let open = OpenToolIntent(); open.tool = .deviceInfo; _ = try await open.perform()
        XCTAssertEqual(ToolRouter.shared.path, [.deviceInfo]); XCTAssertEqual(ToolRouter.shared.selectedTab, 0)
    }
    @MainActor func testPurchaseEntitlementAndRefund() async throws {
        if BuildDistribution.isSideload { throw XCTSkip("StoreKit purchasing is disabled in GitHub sideload builds") }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ShunBox", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let store = SupportStore.shared
        await store.refreshEntitlement(); XCTAssertFalse(store.supported)
        let transaction = try await session.buyProduct(identifier: SupportStore.productID)
        for _ in 0..<20 { await store.refreshEntitlement(); if store.supported { break }; try await Task.sleep(for: .milliseconds(100)) }
        if !store.supported { for await value in Transaction.currentEntitlements { print("StoreKit entitlement diagnostic: \(value)") } }
        XCTAssertTrue(store.supported)
        try session.refundTransaction(identifier: UInt(transaction.id))
        for _ in 0..<20 { await store.refreshEntitlement(); if !store.supported { break }; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(store.supported)
    }
}
