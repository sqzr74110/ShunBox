import UIKit
import CoreImage

/// An exported photographic border. The glass is rendered into pixels, not a UI control.
enum GlassWatermark {
    private static let ci = CIContext(options: [.cacheIntermediates: false])
    static func draw(image: CGImage, size: CGSize, footer: CGFloat, caption: String, metadata: PhotoMetadata, options: ImageOptions, context: CGContext) {
        let area = CGRect(x: 0, y: size.height, width: size.width, height: footer)
        context.saveGState(); context.clip(to: area)
        UIColor(white: 0.94, alpha: 1).setFill(); context.fill(area)
        // A blurred reflection of the source photo gives the glass its local color.
        let scale = min(1, 600 / size.width)
        let input = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blurred = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 15]).cropped(to: input.extent)
        if let background = ci.createCGImage(blurred, from: input.extent) { UIImage(cgImage: background).draw(in: area) }
        UIColor.white.withAlphaComponent(0.78).setFill(); context.fill(area)
        context.restoreGState()
        let inset = size.width * 0.045
        let pill = area.insetBy(dx: inset, dy: footer * 0.17)
        let radius = pill.height / 2
        let path = UIBezierPath(roundedRect: pill, cornerRadius: radius)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: footer * 0.028), blur: footer * 0.10, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        UIColor.white.withAlphaComponent(0.40).setFill(); path.fill()
        context.restoreGState()
        context.saveGState(); path.addClip()
        let colors = [UIColor.white.withAlphaComponent(0.88).cgColor, UIColor.white.withAlphaComponent(0.18).cgColor, UIColor(red: 0.83, green: 0.88, blue: 1, alpha: 0.40).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1]) { context.drawLinearGradient(gradient, start: CGPoint(x: pill.minX, y: pill.minY), end: CGPoint(x: pill.maxX, y: pill.maxY), options: []) }
        context.restoreGState()
        UIColor.white.withAlphaComponent(0.85).setStroke(); path.lineWidth = max(1, size.width / 900); path.stroke()
        let heading = !caption.isEmpty ? caption : options.showCamera && !metadata.camera.isEmpty ? metadata.camera : "SHUNBOX"
        var details: [String] = []
        if options.showCamera && !caption.isEmpty && !metadata.camera.isEmpty { details.append(metadata.camera) }
        if options.showSettings && !metadata.settings.isEmpty { details.append(metadata.settings) }
        if options.showDate && !metadata.date.isEmpty { details.append(metadata.date) }
        let x = pill.minX + radius * 0.65
        let available = pill.width - radius * 1.3
        let hasDetails = !details.isEmpty
        line(heading, rect: CGRect(x: x, y: pill.minY + pill.height * (hasDetails ? 0.17 : 0.30), width: available, height: pill.height * 0.34), font: .systemFont(ofSize: size.width * 0.031, weight: .semibold), color: UIColor(white: 0.12, alpha: 1))
        if hasDetails { line(details.joined(separator: "   /   "), rect: CGRect(x: x, y: pill.minY + pill.height * 0.57, width: available, height: pill.height * 0.24), font: .monospacedSystemFont(ofSize: size.width * 0.018, weight: .medium), color: UIColor(white: 0.30, alpha: 1)) }
    }
    private static func line(_ text: String, rect: CGRect, font: UIFont, color: UIColor) {
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        let fitting = font.withSize(font.pointSize * min(1, rect.width / max(1, width)))
        (text as NSString).draw(in: rect, withAttributes: [.font: fitting, .foregroundColor: color, .kern: fitting.pointSize * 0.035])
    }
}
