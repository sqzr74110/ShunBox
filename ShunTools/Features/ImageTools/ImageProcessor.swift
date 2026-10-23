import UIKit
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import CoreImage

struct ImageOptions: Sendable, Hashable {
    var format = "jpeg"
    var quality = 0.85
    var maxDimension = 2400
    var watermark = ""
    var watermarkStyle: WatermarkStyle = .none
    var showCamera = true
    var showSettings = true
    var showDate = false
    var targetBytes = 0
}
actor ImageProcessor {
    static let shared = ImageProcessor()
    func process(_ urls: [URL], options: ImageOptions) throws -> [URL] {
        if options.format == "pdf" { return [try makePDF(urls, options: options)] }
        var outputs: [URL] = []
        do {
            for url in urls { try Task.checkCancellation(); outputs.append(try autoreleasepool { try convertToBudget(url, options: options) }) }
            return outputs
        } catch { for url in outputs { try? FileManager.default.removeItem(at: url) }; throw error }
    }
    private func convertToBudget(_ url: URL, options: ImageOptions) throws -> URL {
        var configuration = options
        for attempt in 0..<18 {
            try Task.checkCancellation()
            let output = try convert(url, options: configuration)
            let bytes = (try output.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            if options.targetBytes <= 0 || bytes <= options.targetBytes { return output }
            try? FileManager.default.removeItem(at: output.deletingLastPathComponent())
            if attempt < 4 { configuration.quality = max(0.12, configuration.quality * 0.7) }
            else { configuration.maxDimension = max(64, Int(Double(configuration.maxDimension) * 0.75)) }
        }
        throw ToolFailure(message: L("无法在当前设置下达到目标体积，请提高体积上限或关闭水印。"))
    }
    private func makePDF(_ urls: [URL], options: ImageOptions) throws -> URL {
        guard !urls.isEmpty else { throw ToolFailure(message: L("请先选择图片。")) }
        var images: [URL] = []
        defer { for url in images { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) } }
        var configuration = options; configuration.format = "jpeg"
        for url in urls { try Task.checkCancellation(); images.append(try autoreleasepool { try convert(url, options: configuration) }) }
        let output = try FileStore.destination(L("照片合集.pdf"))
        var failure: Error?
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try renderer.writePDF(to: output) { context in
            for url in images {
                do { try Task.checkCancellation() } catch { failure = error; break }
                autoreleasepool {
                    guard let image = UIImage(contentsOfFile: url.path) else { failure = ToolFailure(message: L("无法读取处理后的图片。")); return }
                    context.beginPage()
                    let scale = min(555 / image.size.width, 802 / image.size.height)
                    let rect = CGRect(x: (595 - image.size.width * scale) / 2, y: (842 - image.size.height * scale) / 2, width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: rect)
                }
                if failure != nil { break }
            }
        }
        if let failure { try? FileManager.default.removeItem(at: output); throw failure }
        return output
    }
    func renderPreview(_ url: URL, options: ImageOptions) throws -> Data? {
        var configuration = options; configuration.format = "png"; configuration.maxDimension = min(900, options.maxDimension)
        let result = try convert(url, options: configuration)
        defer { try? FileManager.default.removeItem(at: result.deletingLastPathComponent()) }
        return try Data(contentsOf: result)
    }
    private func convert(_ url: URL, options: ImageOptions) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(64, min(options.maxDimension, 8192)), kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw ToolFailure(message: L("无法读取图片。请选择有效的 JPG、PNG 或 HEIC 文件。")) }
        try Task.checkCancellation()
        let metadata = PhotoMetadata.read(source)
        let size = CGSize(width: image.width, height: image.height)
        let glass = options.watermarkStyle == .glassFooter
        let framed = options.watermarkStyle == .whiteFrame || options.watermarkStyle == .blackFrame || glass
        let footer = framed ? max(80, size.width * 0.19) : 0
        let canvas = CGSize(width: size.width, height: size.height + footer)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = options.format == "jpeg"; format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            if format.opaque { UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)) }
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
            let caption = options.watermark.trimmingCharacters(in: .whitespacesAndNewlines)
            if glass {
                GlassWatermark.draw(image: image, size: size, footer: footer, caption: caption, metadata: metadata, options: options, context: context.cgContext)
            } else if framed {
                let dark = options.watermarkStyle == .blackFrame
                (dark ? UIColor(white: 0.07, alpha: 1) : UIColor.white).setFill()
                context.fill(CGRect(x: 0, y: size.height, width: size.width, height: footer))
                let primary = dark ? UIColor.white : UIColor.black
                let secondary = dark ? UIColor.lightGray : UIColor.darkGray
                let inset = size.width * 0.045
                let heading = !caption.isEmpty ? caption : options.showCamera && !metadata.camera.isEmpty ? metadata.camera : "PHOTOGRAPHY"
                drawLine(heading, rect: CGRect(x: inset, y: size.height + footer * 0.18, width: size.width - inset * 2, height: footer * 0.3), font: .systemFont(ofSize: max(10, size.width * 0.042), weight: .semibold), color: primary)
                var details: [String] = []
                if options.showCamera && !caption.isEmpty && !metadata.camera.isEmpty { details.append(metadata.camera) }
                if options.showSettings && !metadata.settings.isEmpty { details.append(metadata.settings) }
                if options.showDate && !metadata.date.isEmpty { details.append(metadata.date) }
                drawLine(details.joined(separator: "  |  "), rect: CGRect(x: inset, y: size.height + footer * 0.57, width: size.width - inset * 2, height: footer * 0.26), font: .monospacedSystemFont(ofSize: max(7, size.width * 0.024), weight: .regular), color: secondary)
            } else if options.watermarkStyle == .text {
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right
                let shadow = NSShadow(); shadow.shadowColor = UIColor.black.withAlphaComponent(0.65); shadow.shadowBlurRadius = 3
                ((caption.isEmpty ? "SHUNBOX" : caption) as NSString).draw(in: CGRect(x: size.width * 0.04, y: size.height * 0.84, width: size.width * 0.92, height: size.height * 0.14), withAttributes: [.font: UIFont.systemFont(ofSize: max(12, size.width / 28), weight: .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.85), .shadow: shadow, .paragraphStyle: paragraph])
            }
        }
        guard let type = ImageFormat.available.first(where: { $0.id == options.format })?.type else { throw ToolFailure(message: L("当前系统没有该格式的图片编码器。")) }
        let output = try FileStore.destination(url.deletingPathExtension().lastPathComponent + L("-处理.") + (type.preferredFilenameExtension ?? "jpg"))
        guard let cg = rendered.cgImage, let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else { throw ToolFailure(message: L("此设备不支持所选输出格式。")) }
        // Only fresh pixel data and encoding properties are written. No source EXIF, GPS, IPTC or XMP is copied.
        CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: options.quality, kCGImagePropertyOrientation: 1] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { try? FileManager.default.removeItem(at: output); throw ToolFailure(message: L("图片编码失败，请尝试其他格式或较小尺寸。")) }
        try Task.checkCancellation()
        return output
    }
    private func drawLine(_ text: String, rect: CGRect, font: UIFont, color: UIColor) {
        let measured = (text as NSString).size(withAttributes: [.font: font]).width
        let fitting = font.withSize(font.pointSize * min(1, rect.width / max(measured, 1)))
        (text as NSString).draw(in: rect, withAttributes: [.font: fitting, .foregroundColor: color])
    }
    func metadata(_ url: URL) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return PhotoMetadata() }
        return PhotoMetadata.read(source)
    }
    func preview(_ url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1000] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
}
