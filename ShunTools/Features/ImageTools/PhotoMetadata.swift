import Foundation
import ImageIO

struct PhotoMetadata: Sendable {
    var camera = ""
    var lens = ""
    var settings = ""
    var date = ""
    static func read(_ source: CGImageSource) -> PhotoMetadata {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let camera = tiff[kCGImagePropertyTIFFModel] as? String ?? ""
        let lens = exif[kCGImagePropertyExifLensModel] as? String ?? ""
        var pieces: [String] = []
        if let focal = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? NSNumber, focal.doubleValue > 0 { pieces.append("\(focal.intValue)mm") }
        else if let focal = exif[kCGImagePropertyExifFocalLength] as? NSNumber { pieces.append(String(format: "%.1fmm", focal.doubleValue)) }
        if let aperture = exif[kCGImagePropertyExifFNumber] as? NSNumber { pieces.append(String(format: "ƒ/%.1f", aperture.doubleValue)) }
        if let shutter = exif[kCGImagePropertyExifExposureTime] as? NSNumber, shutter.doubleValue > 0 {
            pieces.append(shutter.doubleValue < 1 ? "1/\(Int((1 / shutter.doubleValue).rounded()))s" : String(format: "%.1fs", shutter.doubleValue))
        }
        if let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.first { pieces.append("ISO \(iso.intValue)") }
        return PhotoMetadata(camera: camera, lens: lens, settings: pieces.joined(separator: "  ·  "), date: exif[kCGImagePropertyExifDateTimeOriginal] as? String ?? "")
    }
}
enum WatermarkStyle: String, CaseIterable, Sendable {
    case none, glassFooter, text, whiteFrame, blackFrame
    var title: String { switch self { case .none: L("无水印"); case .glassFooter: L("玻璃胶囊"); case .text: L("简洁叠字"); case .whiteFrame: L("经典白边"); case .blackFrame: L("极简黑边") } }
}
