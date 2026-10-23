import AppIntents
import UniformTypeIdentifiers
import SwiftUI

enum ShortcutTool: String, AppEnum {
    case image, ringtone, deviceInfo, deviceCheck, qr, pdf
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tool")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .image: "Image Studio", .ringtone: "Ringtone Maker", .deviceInfo: "Device Info", .deviceCheck: "Device Check", .qr: "QR Code", .pdf: "PDF Organizer"
    ]
}
@MainActor @Observable final class ToolRouter {
    static let shared = ToolRouter()
    var path: [Tool] = []
    var selectedTab = 0
    func open(_ tool: Tool) { selectedTab = 0; path = [tool] }
}
struct OpenToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tool"
    static var description = IntentDescription("Open a ShunBox tool. Files are selected only by you.")
    static var openAppWhenRun = true
    @Parameter(title: "Tool", default: .image) var tool: ShortcutTool
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$tool)") }
    @MainActor func perform() async throws -> some IntentResult {
        ToolRouter.shared.open(Tool(rawValue: tool.rawValue) ?? .image)
        return .result()
    }
}
enum ShortcutImageFormat: String, AppEnum {
    case jpeg, png, heic
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Image Format")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.jpeg: "JPG", .png: "PNG", .heic: "HEIC"]
}
struct ConvertImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Image"
    static var description = IntentDescription("Convert an image on-device and remove source metadata. Returns a file; does not overwrite the original.")
    @Parameter(title: "Image", supportedContentTypes: [.image]) var image: IntentFile
    @Parameter(title: "Image Format", default: .jpeg) var format: ShortcutImageFormat
    static var parameterSummary: some ParameterSummary { Summary("Convert \(\.$image) to \(\.$format)") }
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let source = try FileStore.destination(image.filename)
        try image.data.write(to: source)
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        var options = ImageOptions(); options.format = format.rawValue
        let result = try await ImageProcessor.shared.process([source], options: options)[0]
        return .result(value: IntentFile(fileURL: result, type: UTType(filenameExtension: result.pathExtension)))
    }
}
struct GenerateQRIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate QR Code"
    static var description = IntentDescription("Create a QR image from text or a URL, entirely on-device.")
    @Parameter(title: "Text or URL") var text: String
    static var parameterSummary: some ParameterSummary { Summary("Create a QR code from \(\.$text)") }
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let result = try await QRProcessor.shared.generate(text)
        return .result(value: IntentFile(fileURL: result, type: .png))
    }
}
struct ShunBoxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenToolIntent(), phrases: ["Open \(\.$tool) in \(.applicationName)", "Open tools in \(.applicationName)"], shortTitle: "Open Tool", systemImageName: "square.grid.2x2")
        AppShortcut(intent: ConvertImageIntent(), phrases: ["Convert an image with \(.applicationName)"], shortTitle: "Convert Image", systemImageName: "photo")
        AppShortcut(intent: GenerateQRIntent(), phrases: ["Create a QR code with \(.applicationName)"], shortTitle: "Generate QR Code", systemImageName: "qrcode")
    }
}
struct ShortcutsHelpView: View {
    var body: some View {
        List {
            Section(L("快速操作")) {
                ShortcutsLink()
                SiriTipView(intent: OpenToolIntent())
                Text(L("在快捷指令 App 中搜索顺匣，可添加打开工具、转换图片、生成二维码三个操作。转换与生成会返回文件，可继续连接保存文件或分享操作。"))
            }
            Section("Siri / Apple Intelligence") {
                Text(L("可通过 Siri 运行已添加的快捷指令。系统智能功能的可用性取决于设备、系统语言与地区；本应用不会自行上传你的文件给 AI 服务。"))
                Text(L("此版本提供 App Intents 操作，不保证任意自然语言都能直接执行，也不提供屏幕内容读取或自动安装铃声。"))
            }
        }.navigationTitle(L("快捷指令与 Siri"))
    }
}
