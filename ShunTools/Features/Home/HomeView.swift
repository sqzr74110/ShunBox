import SwiftUI

struct ToolIcon: View {
    let tool: Tool
    var body: some View { Image(systemName: tool.symbol).font(.title2).foregroundStyle(tool.tint).frame(width: 48, height: 48).background(tool.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true) }
}
struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 12) {
                        Label(L("随手处理 · 安心留在本机"), systemImage: "lock.shield").font(.subheadline).foregroundStyle(Color.accentColor)
                        Spacer(minLength: 0)
                        Image("Mascot").resizable().scaledToFit().frame(width: 58, height: 58).accessibilityHidden(true)
                    }
                    Text(L("让每一份文件\n恰到好处。")).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text(L("从一张照片、一段声音开始。\n简单实用，不打扰。")) .foregroundStyle(.secondary)
                    NavigationLink(value: Tool.image) { Label(L("打开图片工坊"), systemImage: "arrow.up.right").fontWeight(.semibold).padding(.vertical, 5) }.buttonStyle(.glassProminent).tint(.brandButton)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(LinearGradient(colors: [Color.indigo.opacity(0.13), Color.pink.opacity(0.08), Color.cyan.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("快速开始")).font(.title2.bold())
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { quick(.files); quick(.ringtone); quick(.image) }
                    } else {
                        HStack(spacing: 12) { quick(.files); quick(.ringtone); quick(.image) }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("为日常而备")).font(.title2.bold())
                    ForEach([Tool.image, .ringtone, .videoAudio, .imagePDF, .pdf, .qr, .deviceInfo, .deviceCheck]) { tool in
                        NavigationLink(value: tool) { HStack(spacing: 14) { ToolIcon(tool: tool); VStack(alignment: .leading, spacing: 5) { Text(tool.title).font(.headline).foregroundStyle(.primary); Text(tool.subtitle).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary) }.padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }.buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("最近使用")).font(.title2.bold())
                    if library.recent.isEmpty { Label(L("处理过的工具会出现在这里。"), systemImage: "clock").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8) }
                    ForEach(library.recent) { tool in NavigationLink(value: tool) { Label(tool.title, systemImage: tool.symbol) }.padding(.vertical, 6) }
                }
                SupportCard()
                Label(L("无需账户 · 本地处理"), systemImage: "checkmark.shield").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom)
            }.padding(20)
        }.background(BrandBackground()).navigationTitle(L("工具箱"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel(L("设置")) } }
            .navigationDestination(for: Tool.self) { ToolDestination(tool: $0) }
    }
    private func quick(_ tool: Tool) -> some View {
        NavigationLink(value: tool) { VStack(spacing: 12) { Image(systemName: tool.symbol).font(.title2); Text(tool == .files ? L("导入文件") : tool == .ringtone ? L("铃声提示音") : L("相机水印")).font(.subheadline.weight(.medium)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 80).padding(.vertical, 14).padding(.horizontal, 10).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }.buttonStyle(.plain).foregroundStyle(tool.tint)
    }
}
struct CatalogView: View {
    @Environment(LibraryStore.self) private var library
    @State private var search = ""
    @State private var favoritesOnly = false
    var body: some View {
        List {
            Section { Toggle(L("只看收藏"), systemImage: "star", isOn: $favoritesOnly) }
            ForEach([L("图片"), L("音频"), L("文件"), L("视频"), L("实用")], id: \.self) { category in
                let tools = Tool.allCases.filter { $0.category == category && (!favoritesOnly || library.favorites.contains($0.id)) && (search.isEmpty || ($0.title + $0.subtitle).localizedCaseInsensitiveContains(search)) }
                if !tools.isEmpty { Section(category) { ForEach(tools) { tool in
                    NavigationLink(value: tool) { HStack(spacing: 12) { ToolIcon(tool: tool); VStack(alignment: .leading, spacing: 4) { Text(tool.title); Text(tool.subtitle).font(.caption).foregroundStyle(.secondary) }; if library.favorites.contains(tool.id) { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel(L("已收藏")) } } }
                        .swipeActions(edge: .leading) { Button(library.favorites.contains(tool.id) ? L("取消收藏") : L("收藏"), systemImage: "star") { library.toggle(tool) }.tint(.orange) }
                        .contextMenu { Button(library.favorites.contains(tool.id) ? L("取消收藏") : L("收藏"), systemImage: "star") { library.toggle(tool) } }
                } } }
            }
            Section { Label(L("更多工具持续加入，全部在本机处理"), systemImage: "sparkles").foregroundStyle(.secondary).font(.footnote) }
        }.navigationTitle(L("全部工具")).searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: L("搜索工具或功能"))
            .navigationDestination(for: Tool.self) { ToolDestination(tool: $0) }
    }
}
