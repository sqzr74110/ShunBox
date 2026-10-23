import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
@testable import ShunTools

final class ProcessingTests: XCTestCase {
    func imageFixture(alpha: Bool = false) throws -> URL {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 60, height: 80)) }
        let url = try FileStore.destination(alpha ? "private-photo.png" : "private-photo.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, (alpha ? UTType.png : UTType.jpeg).identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 31.2, kCGImagePropertyGPSLatitudeRef: "N"], kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:23 10:00:00", kCGImagePropertyExifFNumber: 1.8, kCGImagePropertyExifExposureTime: 0.01, kCGImagePropertyExifISOSpeedRatings: [100], kCGImagePropertyExifFocalLenIn35mmFilm: 24], kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Fixture Camera"], kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination)); return url
    }
    func testImagePrivacyOrientationAndDimensions() async throws {
        let input = try imageFixture()
        let inputSource = try XCTUnwrap(CGImageSourceCreateWithURL(input as CFURL, nil))
        let original = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(inputSource, 0, nil) as? [CFString: Any])
        XCTAssertNotNil(original[kCGImagePropertyGPSDictionary]); XCTAssertEqual(original[kCGImagePropertyOrientation] as? Int, 6)
        let outputs = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "png", quality: 0.8, maxDimension: 64, watermark: ""))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(outputs[0] as CFURL, nil))
        let metadata = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertNil(metadata[kCGImagePropertyGPSDictionary]); XCTAssertNil((metadata[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal])
        let cg = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(cg.height, 64); XCTAssertLessThan(cg.width, cg.height)
        XCTAssertTrue([CGImageAlphaInfo.premultipliedLast, .premultipliedFirst, .last, .first].contains(cg.alphaInfo))
    }
    func testImageFormatsAndBatch() async throws {
        let input = try imageFixture(alpha: true)
        for format in ["jpeg", "png", "heic"] {
            let outputs = try await ImageProcessor.shared.process([input, input], options: ImageOptions(format: format, quality: 0.5, maxDimension: 120, watermark: "ShunTools", watermarkStyle: .text))
            XCTAssertEqual(outputs.count, 2); XCTAssertNotEqual(outputs[0], outputs[1])
            for url in outputs { XCTAssertNotNil(CGImageSourceCreateWithURL(url as CFURL, nil)); XCTAssertGreaterThan((try Data(contentsOf: url)).count, 0) }
        }
    }
    func testInvalidImageAndCancellation() async throws {
        let input = try FileStore.destination("broken.jpg"); try Data("invalid".utf8).write(to: input)
        do { _ = try await ImageProcessor.shared.process([input], options: .init()); XCTFail("Must reject corrupt image") } catch {}
        let valid = try imageFixture()
        let task = Task { try await ImageProcessor.shared.process([valid], options: .init()) }; task.cancel()
        do { _ = try await task.value; XCTFail("Must cancel") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    func pdfFixture(pages: Int) throws -> URL {
        let url = try FileStore.destination("source.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
        try renderer.writePDF(to: url) { context in for i in 1...pages { context.beginPage(); ("Page \(i)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)]) } }
        return url
    }
    func testPDFMergeExtractAndInvalidRange() async throws {
        let a = try pdfFixture(pages: 3), b = try pdfFixture(pages: 2)
        let merged = try await FileProcessor.shared.pdf([a, b], pages: nil)
        XCTAssertEqual(PDFDocument(url: merged)?.pageCount, 5)
        let extracted = try await FileProcessor.shared.pdf([a], pages: 2...3)
        XCTAssertEqual(PDFDocument(url: extracted)?.pageCount, 2)
        XCTAssertTrue(PDFDocument(url: extracted)?.page(at: 0)?.string?.contains("Page 2") == true)
        do { _ = try await FileProcessor.shared.pdf([a], pages: 1...4); XCTFail("Must reject invalid range") } catch {}
    }
    func testRenameAndImportPreserveOriginal() async throws {
        let source = try FileStore.destination("original.txt"); let data = Data("hello".utf8); try data.write(to: source)
        let imported = try FileStore.importFile(source)
        let renamed = try await FileProcessor.shared.rename(imported, name: "副本")
        XCTAssertEqual(renamed.lastPathComponent, "副本.txt"); XCTAssertEqual(try Data(contentsOf: renamed), data); XCTAssertEqual(try Data(contentsOf: source), data)
        do { _ = try await FileProcessor.shared.rename(imported, name: "../bad"); XCTFail("Must reject traversal") } catch {}
    }
    func audioFixture() throws -> URL {
        let url = try FileStore.destination("tone.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200)); buffer.frameLength = 88200
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for i in 0..<88200 { samples[i] = Float(sin(Double(i) * 440 * 2 * .pi / 44100)) * 0.5 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer)
        return url
    }
    func testAudioTrimFadeAndRingtone() async throws {
        let input = try audioFixture()
        let info = try await AudioProcessor.shared.inspect(input); XCTAssertEqual(info.duration, 2, accuracy: 0.05)
        let output = try await AudioProcessor.shared.export(input, start: 0.25, end: 1.75, fade: 0.25, ringtone: false)
        let result = try await AudioProcessor.shared.inspect(output); XCTAssertEqual(result.duration, 1.5, accuracy: 0.1)
        let file = try AVAudioFile(forReading: output)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))); try file.read(into: buffer)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0]); let n = Int(buffer.frameLength)
        func energy(_ range: Range<Int>) -> Float { range.reduce(0) { $0 + abs(samples[$1]) } / Float(range.count) }
        XCTAssertLessThan(energy(0..<1000), energy((n/2)..<(n/2+1000)) * 0.3)
        XCTAssertLessThan(energy((n-1000)..<n), energy((n/2)..<(n/2+1000)) * 0.3)
        let ringtone = try await AudioProcessor.shared.export(input, start: 0, end: 1, fade: 0, ringtone: true)
        XCTAssertEqual(ringtone.pathExtension, "m4r")
        do { _ = try await AudioProcessor.shared.export(input, start: 1, end: 0, fade: 0, ringtone: false); XCTFail("Must reject invalid range") } catch {}
    }
    func testCameraWatermarkAndImagePDF() async throws {
        let input = try imageFixture()
        let metadata = await ImageProcessor.shared.metadata(input)
        XCTAssertEqual(metadata.camera, "Fixture Camera")
        XCTAssertTrue(metadata.settings.contains("ISO 100")); XCTAssertTrue(metadata.settings.contains("24mm")); XCTAssertTrue(metadata.settings.contains("1/100s"))
        for style in [WatermarkStyle.whiteFrame, .blackFrame] {
            let output = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "png", maxDimension: 120, watermarkStyle: style))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(output[0] as CFURL, nil))
            let cg = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(cg.width, 80); XCTAssertEqual(cg.height, 200)
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]); XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
            let rebuilt = await ImageProcessor.shared.metadata(output[0]); XCTAssertTrue(rebuilt.camera.isEmpty); XCTAssertTrue(rebuilt.date.isEmpty)
        }
        let pdf = try await ImageProcessor.shared.process([input, input], options: ImageOptions(format: "pdf", watermarkStyle: .whiteFrame))
        XCTAssertEqual(PDFDocument(url: pdf[0])?.pageCount, 2)
    }
    func testAllInstalledImageEncoders() async throws {
        let input = try imageFixture(alpha: true)
        for format in ImageFormat.available {
            let outputs = try await ImageProcessor.shared.process([input], options: ImageOptions(format: format.id, maxDimension: 120))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(outputs[0] as CFURL, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, format.type.identifier)
        }
    }
    func testPCMFormatsAndWaveform() async throws {
        let input = try audioFixture()
        let peaks = try await AudioProcessor.shared.waveform(input)
        XCTAssertEqual(peaks.count, 120); XCTAssertGreaterThan(peaks.max() ?? 0, 0.9)
        for format in ["wav", "aiff", "caf"] {
            let output = try await AudioProcessor.shared.export(input, start: 0.2, end: 1.2, fade: 0.1, ringtone: false, format: format)
            let info = try await AudioProcessor.shared.inspect(output)
            XCTAssertEqual(info.duration, 1, accuracy: 0.05); XCTAssertEqual(output.pathExtension, format)
        }
    }
    func testQRRoundTrip() async throws {
        let payload = "ShunTools 离线二维码 https://example.com"
        let url = try await QRProcessor.shared.generate(payload)
        let decoded = try await QRProcessor.shared.recognize(url)
        XCTAssertEqual(decoded, [payload])
        do { _ = try await QRProcessor.shared.generate(""); XCTFail("Must reject empty input") } catch {}
    }
    func testSyncFolderCopyAndRead() async throws {
        let source = try FileStore.destination("source.txt"); let data = Data("sync fixture".utf8); try data.write(to: source)
        let folder = try FileStore.destination("folder"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bookmark = try folder.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
        let saved = try await SyncFileAccess.shared.copy(source, bookmark: bookmark)
        let list = try await SyncFileAccess.shared.list(bookmark)
        XCTAssertEqual(list.count, 1); XCTAssertEqual(list[0].url, saved)
        let download = try await SyncFileAccess.shared.download(saved, bookmark: bookmark)
        XCTAssertEqual(try Data(contentsOf: download), data); XCTAssertEqual(try Data(contentsOf: source), data)
    }

    func testTargetImageBudget() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800), format: format).image { context in
            for x in stride(from: 0, to: 1200, by: 4) { for y in stride(from: 0, to: 800, by: 4) {
                UIColor(red: CGFloat((x * 13 + y) % 255) / 255, green: CGFloat((y * 17 + x) % 255) / 255, blue: CGFloat((x * y) % 255) / 255, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            } }
        }
        let input = try FileStore.destination("detailed.png"); try XCTUnwrap(image.pngData()).write(to: input)
        let output = try await ImageProcessor.shared.process([input], options: ImageOptions(format: "jpeg", maxDimension: 1200, targetBytes: 50_000))
        XCTAssertLessThanOrEqual(try Data(contentsOf: output[0]).count, 50_000)
    }
    func testMovieAudioExtraction() async throws {
        let audio = try audioFixture()
        let asset = AVURLAsset(url: audio)
        let composition = AVMutableComposition()
        let sourceTracks = try await asset.loadTracks(withMediaType: .audio)
        let source = try XCTUnwrap(sourceTracks.first)
        let track = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)), of: source, at: .zero)
        let movie = try FileStore.destination("audio-container.mov")
        let session = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await session.export(to: movie, as: .mov)
        let result = try await AudioProcessor.shared.prepare(movie)
        XCTAssertEqual(result.pathExtension, "m4a")
        let info = try await AudioProcessor.shared.inspect(result); XCTAssertEqual(info.duration, 2, accuracy: 0.1)
    }

}
