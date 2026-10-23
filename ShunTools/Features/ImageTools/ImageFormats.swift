import Foundation
import UniformTypeIdentifiers
import ImageIO

struct ImageFormat: Identifiable {
    let id: String
    let title: String
    let type: UTType
    static let all: [ImageFormat] = [
        .init(id: "jpeg", title: L("JPG · 通用分享"), type: .jpeg),
        .init(id: "png", title: L("PNG · 透明图片"), type: .png),
        .init(id: "heic", title: L("HEIC · 节省空间"), type: .heic),
        .init(id: "tiff", title: L("TIFF · 图像交换"), type: .tiff),
        .init(id: "bmp", title: L("BMP · 兼容位图"), type: .bmp),
        .init(id: "gif", title: L("GIF · 静态单帧"), type: .gif),
        .init(id: "webp", title: "WebP", type: .webP)
    ]
    static var available: [ImageFormat] {
        let encoders = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return all.filter { encoders.contains($0.type.identifier) }
    }
}
