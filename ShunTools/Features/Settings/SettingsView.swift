import SwiftUI
struct SettingsView: View {
    @AppStorage("appLanguage") private var language = "system"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("imageFormat") private var imageFormat = "jpeg"
    @Environment(LibraryStore.self) private var library
    @State private var confirm = false
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("顺匣 · 你的随身工具箱")).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(L("图片、音频与文件，随手处理。")).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
            }.listRowBackground(LinearGradient(colors: [Color.indigo.opacity(0.10), Color.pink.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Section(L("使用偏好")) {
                Picker(L("语言"), selection: $language) {
                    Text(L("跟随系统")).tag("system")
                    ForEach(AppLanguage.supported, id: \.self) { code in Text(AppLanguage.nativeName(code)).tag(code) }
                }.accessibilityIdentifier("settings.language")
                Picker(L("外观"), selection: $appearance) { Text(L("跟随系统")).tag("system"); Text(L("浅色")).tag("light"); Text(L("深色")).tag("dark") }
                Picker(L("默认图片格式"), selection: $imageFormat) { Text("JPG").tag("jpeg"); Text("PNG").tag("png"); Text("HEIC").tag("heic") }
            }
            Section(L("同步")) { NavigationLink(L("iCloud 与文件同步")) { SyncSettingsView() } }
            Section(L("数据与隐私")) {
                NavigationLink(L("隐私说明")) { ScrollView { VStack(alignment: .leading, spacing: 20) { Label(L("你的文件，只属于你"), systemImage: "lock.shield").font(.title2.bold()); Text(L("所有转换均在本机完成。无需登录，默认不上传文件，不使用广告或跟踪 SDK。选择同步文件夹并启用保存后，结果由你选择的 iCloud Drive 或其他文件提供商同步。照片选择通过系统选择器完成；仅在保存时请求添加照片的权限。")); Text(L("处理结果自动保存在本机媒体库，直到你主动删除或卸载应用。导入副本仍为临时缓存。媒体库不随清理缓存删除；同步仅写入你选择的文件夹。")); Text(L("图片工坊重新编码像素以移除来源元数据。水印、照片中可见的地址等像素内容不会被自动识别或删除。")) }.padding() }.navigationTitle(L("隐私说明")) }
                Button(L("清理临时文件"), systemImage: "trash", role: .destructive) { confirm = true }.disabled(ActivityState.shared.count > 0)
                Button(L("清除最近使用"), systemImage: "clock.arrow.circlepath") { library.clear(); message = L("最近使用已清除。") }
            }
            Section { NavigationLink(L("支持作者")) { SupportView() }; NavigationLink(L("快捷指令与 Siri")) { ShortcutsHelpView() } }
            Section(L("关于")) { NavigationLink(L("支持的格式")) { SupportedFormatsView() }; LabeledContent(L("版本"), value: "0.1.0 (1)"); LabeledContent(L("为 iPhone 设计"), value: "iOS 26+"); Text(L("使用 Apple 原生框架构建。\n离线、轻量，专注每一件小事。")).font(.footnote).foregroundStyle(.secondary) }
        }.scrollContentBackground(.hidden).background(BrandBackground()).navigationTitle(L("设置"))
        .confirmationDialog(L("清理后，尚未保存的处理结果将被移除。"), isPresented: $confirm, titleVisibility: .visible) { Button(L("清理缓存"), role: .destructive) { do { try FileStore.clean(); message = L("临时文件已清理。") } catch { message = error.localizedDescription } } }
        .alert(L("提示"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(message ?? "") }
    }
}
