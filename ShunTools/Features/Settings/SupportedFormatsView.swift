import SwiftUI
import ImageIO
import UniformTypeIdentifiers
struct SupportedFormatsView: View {
    var body: some View {
        List {
            Section(L("图片导出 · 当前设备可用")) { ForEach(ImageFormat.available) { format in LabeledContent(format.title, value: format.type.preferredFilenameExtension?.uppercased() ?? format.id) }; Text(L("PDF：多张图片合成 A4 文档")) }
            Section(L("图片导入 · 当前系统解码器")) {
                let identifiers = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
                ForEach(identifiers, id: \.self) { identifier in Text(UTType(identifier)?.localizedDescription ?? identifier) }
            }
            Section(L("音频")) {
                LabeledContent(L("导出"), value: "M4A · M4R · WAV · AIFF · CAF")
                Text(L("常用输入：MP3、M4A、AAC、WAV、AIFF、CAF、FLAC。实际能否读取取决于文件内部编码、系统解码器与内容保护。"))
                Text(L("MP3 目前仅导入，不提供 MP3 编码。DRM 保护的音乐不能转换。视频导入会先提取为 M4A，PCM 输出不会恢复原文件已丢失的音质。"))
            }
            Section(L("视频与文件")) {
                Text(L("MOV / MP4 等系统支持的视频可提取音轨；无音轨、加密或不支持的编码会明确报错。"))
                Text(L("PDF：合并、连续页提取。文件管理可导入系统文件选择器允许的文件；Quick Look 是否可预览由系统决定。"))
            }
        }.navigationTitle(L("支持的格式"))
    }
}
