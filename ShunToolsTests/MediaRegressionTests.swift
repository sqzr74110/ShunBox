import XCTest
import UIKit
import ImageIO
@testable import ShunTools

final class MediaRegressionTests: XCTestCase {
    func testLibrarySurvivesSourceRemovalAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = MediaArchive(root: root)
        let source = try FileStore.destination("same-name.txt")
        try Data("first".utf8).write(to: source)
        let first = try await archive.save(source)
        try Data("second".utf8).write(to: source)
        let second = try await archive.save(source)
        XCTAssertNotEqual(first, second)
        try FileManager.default.removeItem(at: source)
        let reloaded = MediaArchive(root: root)
        let items = try await reloaded.list(); XCTAssertEqual(items.count, 2)
        XCTAssertEqual(try Data(contentsOf: first), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: second), Data("second".utf8))
        try await reloaded.remove(items[0])
        let remaining = try await reloaded.list(); XCTAssertEqual(remaining.count, 1)
    }
    func testGlassBorderAndEmptyCaptionOverlayRender() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400), format: format).image { context in UIColor.systemBlue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 400)) }
        let input = try FileStore.destination("watermark.png"); try image.pngData()!.write(to: input)
        let plain = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "png"))
        let glass = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "png", watermarkStyle: .glassFooter))
        let text = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "png", watermarkStyle: .text))
        let rendered = try XCTUnwrap(UIImage(contentsOfFile: glass[0].path)?.cgImage)
        XCTAssertEqual(rendered.width, 600); XCTAssertEqual(rendered.height, 514)
        XCTAssertNotEqual(try Data(contentsOf: plain[0]), try Data(contentsOf: text[0]))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(glass[0] as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        XCTAssertNil(properties?[kCGImagePropertyGPSDictionary])
    }
    @MainActor func testMissingPreviewDoesNotPresent() {
        let router = PreviewRouter.shared; router.item = nil; router.error = nil
        router.open(URL(fileURLWithPath: "/missing/preview.pdf"))
        XCTAssertNil(router.item); XCTAssertNotNil(router.error)
        router.error = nil
    }
}
