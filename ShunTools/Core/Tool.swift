import SwiftUI

enum Tool: String, CaseIterable, Identifiable, Codable {
    case image, audio, ringtone, files, pdf, imagePDF, videoAudio, qr, deviceInfo, deviceCheck
    var id: String { rawValue }
    var title: String { switch self { case .image: L("图片工坊"); case .audio: L("音频剪辑"); case .ringtone: L("铃声制作"); case .files: L("文件管理"); case .pdf: L("PDF 整理"); case .imagePDF: L("图片转 PDF"); case .videoAudio: L("视频提取声音"); case .deviceInfo: L("设备信息"); case .deviceCheck: L("设备自检"); case .qr: L("二维码") } }
    var subtitle: String { switch self { case .image: L("相机水印、转换与隐私保护"); case .audio: L("留下恰到好处的片段"); case .ringtone: L("制作你的专属声音"); case .files: L("查看、重命名与分享"); case .pdf: L("合并文档，提取页面"); case .imagePDF: L("多张照片，一份整洁文档"); case .videoAudio: L("从相册视频制作铃声"); case .deviceInfo: L("了解屏幕、电池与存储"); case .deviceCheck: L("屏幕、触控与声音检查"); case .qr: L("离线生成与图片识别") } }
    var symbol: String { switch self { case .image: "photo.on.rectangle.angled"; case .audio: "waveform"; case .ringtone: "bell.badge.waveform"; case .files: "folder"; case .pdf: "doc.richtext"; case .imagePDF: "photo.stack"; case .videoAudio: "video.badge.waveform"; case .deviceInfo: "iphone.gen3"; case .deviceCheck: "checkmark.shield"; case .qr: "qrcode" } }
    var category: String { switch self { case .image: L("图片"); case .audio, .ringtone: L("音频"); case .files, .pdf, .imagePDF: L("文件"); case .videoAudio: L("视频"); case .qr, .deviceInfo, .deviceCheck: L("实用") } }
    var tint: Color { switch self { case .image: .blue; case .audio, .ringtone: .purple; case .files, .pdf, .imagePDF: .orange; case .videoAudio: .purple; case .qr, .deviceInfo, .deviceCheck: .teal } }
    var access: FeatureAccess { .free }
}
enum FeatureAccess { case free, pro }
protocol PurchaseService { func restorePurchases() async throws; func purchasePro() async throws }

@MainActor @Observable final class LibraryStore {
    var recent: [Tool] = (UserDefaults.standard.stringArray(forKey: "recent") ?? []).compactMap(Tool.init(rawValue:))
    var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
    func record(_ tool: Tool) { recent.removeAll { $0 == tool }; recent.insert(tool, at: 0); recent = Array(recent.prefix(5)); UserDefaults.standard.set(recent.map(\.rawValue), forKey: "recent") }
    func toggle(_ tool: Tool) { if favorites.contains(tool.id) { favorites.remove(tool.id) } else { favorites.insert(tool.id) }; UserDefaults.standard.set(Array(favorites), forKey: "favorites") }
    func clear() { recent = []; UserDefaults.standard.removeObject(forKey: "recent") }
}
