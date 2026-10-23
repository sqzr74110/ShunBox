import SwiftUI
import UniformTypeIdentifiers
import ImageIO

struct MediaItem: Identifiable, Sendable {
    let url: URL
    let date: Date
    var id: URL { url }
    var kind: String {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        if type.conforms(to: .image) { return "image" }
        if type.conforms(to: .audio) || url.pathExtension == "m4r" { return "audio" }
        return "file"
    }
}
actor MediaArchive {
    static let shared = MediaArchive()
    let root: URL
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MediaLibrary", isDirectory: true)) { self.root = root }
    func save(_ source: URL) throws -> URL {
        if source.path.hasPrefix(root.path + "/") { return source }
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        do { try FileManager.default.copyItem(at: source, to: target); return target }
        catch { try? FileManager.default.removeItem(at: folder); throw error }
    }
    func list() throws -> [MediaItem] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).flatMap { folder in
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles).map {
                MediaItem(url: $0, date: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            }
        }.sorted { $0.date > $1.date }
    }
    func remove(_ item: MediaItem) throws {
        guard item.url.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { return }
        try FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
    }
    func thumbnail(_ url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 240] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}
struct MediaLibraryView: View {
    @State private var items: [MediaItem] = []
    @State private var filter = "all"
    @State private var search = ""
    @State private var deleting: MediaItem?
    @State private var error: String?
    private var visible: [MediaItem] { items.filter { (filter == "all" || $0.kind == filter) && (search.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        List {
            Section {
                Picker(L("类型"), selection: $filter) {
                    Text(L("全部")).tag("all"); Text(L("图片")).tag("image"); Text(L("音频")).tag("audio"); Text(L("文件")).tag("file")
                }.pickerStyle(.segmented)
                Text(L("处理结果自动保存在本机，清理缓存不会删除媒体库。")).font(.caption).foregroundStyle(.secondary)
            }
            if visible.isEmpty { ContentUnavailableView(L("媒体库"), systemImage: "photo.stack", description: Text(L("完成一次处理，作品就会出现在这里。"))) }
            ForEach(visible) { item in
                HStack(spacing: 14) {
                    Button { PreviewRouter.shared.open(item.url) } label: {
                    HStack(spacing: 14) {
                    MediaThumbnail(item: item)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.url.lastPathComponent).font(.subheadline.weight(.medium)).lineLimit(2)
                        Text(item.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text(FileStore.size(item.url)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    } }.buttonStyle(.plain).accessibilityIdentifier("media." + item.url.lastPathComponent)
                    Menu {
                        Button(L("预览结果"), systemImage: "eye") { PreviewRouter.shared.open(item.url) }
                        ShareLink(item: item.url) { Label(L("分享结果"), systemImage: "square.and.arrow.up") }
                        Button(L("删除"), systemImage: "trash", role: .destructive) { deleting = item }
                    } label: { Image(systemName: "ellipsis.circle").padding(8) }
                }
                    .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.85))
            }
        }.scrollContentBackground(.hidden).background(BrandBackground())
            .navigationTitle(L("媒体库")).searchable(text: $search, prompt: L("搜索文件"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel(L("设置")) } }
            .task { await refresh() }.refreshable { await refresh() }
            .confirmationDialog(L("从媒体库删除？已导出到其他位置的文件不受影响。"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button(L("删除"), role: .destructive) { guard let item = deleting else { return }; Task { do { try await MediaArchive.shared.remove(item); await refresh() } catch { self.error = error.localizedDescription }; deleting = nil } }
            }
            .alert(L("无法读取文件"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func refresh() async { do { items = try await MediaArchive.shared.list() } catch { self.error = error.localizedDescription } }
}
private struct MediaThumbnail: View {
    let item: MediaItem
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: item.kind == "audio" ? "waveform" : "doc.richtext").font(.title2).foregroundStyle(item.kind == "audio" ? .purple : .orange) }
        }.frame(width: 64, height: 64).background(.quaternary, in: RoundedRectangle(cornerRadius: 14)).clipShape(RoundedRectangle(cornerRadius: 14))
            .task(id: item.url) { if item.kind == "image" { image = await MediaArchive.shared.thumbnail(item.url).flatMap(UIImage.init(data:)) } }
    }
}
