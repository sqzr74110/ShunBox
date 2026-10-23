import Foundation
import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct SyncedFile: Identifiable, Sendable { let url: URL; var id: URL { url }; let name: String }
actor SyncFileAccess {
    static let shared = SyncFileAccess()
    private func folder(_ bookmark: Data) throws -> URL {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw ToolFailure(message: L("同步文件夹授权已失效，请重新选择文件夹。")) }
        return url
    }
    func copy(_ source: URL, bookmark: Data) throws -> URL {
        let directory = try folder(bookmark), scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        let destination = directory.appendingPathComponent(source.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString.prefix(8) + "." + source.pathExtension)
        var coordinationError: NSError?, operationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { target in
            do { try FileManager.default.copyItem(at: source, to: target) } catch { operationError = error }
        }
        if let error = coordinationError ?? operationError as NSError? { throw error }; return destination
    }
    func list(_ bookmark: Data) throws -> [SyncedFile] {
        let directory = try folder(bookmark), scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles)
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { SyncedFile(url: $0, name: $0.lastPathComponent) }
    }
    func download(_ file: URL, bookmark: Data) throws -> URL {
        let directory = try folder(bookmark), scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        return try FileStore.importFile(file)
    }
}
@MainActor @Observable final class DocumentSync {
    static let shared = DocumentSync()
    var enabled = UserDefaults.standard.bool(forKey: "sync.enabled") { didSet { UserDefaults.standard.set(enabled, forKey: "sync.enabled") } }
    var folderName = UserDefaults.standard.string(forKey: "sync.name") ?? L("未选择")
    var message = ""
    var files: [SyncedFile] = []
    var busy = false
    private var uploaded = Set<URL>()
    private var inFlight = Set<URL>()
    var configured: Bool { UserDefaults.standard.data(forKey: "sync.bookmark") != nil }
    func choose(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: "sync.bookmark"); folderName = url.lastPathComponent
        UserDefaults.standard.set(folderName, forKey: "sync.name"); uploaded = []; files = []; message = L("文件夹已连接。是否自动保存结果由下方开关控制。")
    }
    func save(_ url: URL, automatic: Bool = false) async {
        guard !automatic || enabled, !uploaded.contains(url), !inFlight.contains(url), let bookmark = UserDefaults.standard.data(forKey: "sync.bookmark") else { return }
        inFlight.insert(url); defer { inFlight.remove(url) }
        do { _ = try await SyncFileAccess.shared.copy(url, bookmark: bookmark); uploaded.insert(url); message = L("已复制到所选文件夹；云端上传进度由文件提供商管理。") }
        catch { message = L("同步失败：{0}", String(describing: error.localizedDescription)) }
    }
    func refresh() async {
        guard !busy, let bookmark = UserDefaults.standard.data(forKey: "sync.bookmark") else { return }; busy = true; defer { busy = false }
        do { files = try await SyncFileAccess.shared.list(bookmark); message = L("已读取 {0} 个文件。", String(describing: files.count)) } catch { message = error.localizedDescription }
    }
    func localCopy(_ file: URL) async throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: "sync.bookmark") else { throw ToolFailure(message: L("请先选择同步文件夹。")) }
        return try await SyncFileAccess.shared.download(file, bookmark: bookmark)
    }
    func disconnect() { enabled = false; UserDefaults.standard.removeObject(forKey: "sync.bookmark"); UserDefaults.standard.removeObject(forKey: "sync.name"); folderName = L("未选择"); files = []; uploaded = []; message = L("已断开连接，文件夹中的文件不会被删除。") }
}
struct SyncSettingsView: View {
    @Bindable private var sync = DocumentSync.shared
    @State private var selecting = false
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Label(L("你的结果，随身可用"), systemImage: "icloud").font(.headline)
                Text(L("选择 iCloud Drive 中的专用文件夹，其他设备选择同一个文件夹，即可读取其中的结果。文件只在你选择保存或开启自动保存后写入。"))
                Button(L("选择 iCloud Drive 文件夹"), systemImage: "folder.badge.plus") { selecting = true }
                LabeledContent(L("当前文件夹"), value: sync.folderName)
                Toggle(L("自动保存结果到文件夹"), isOn: $sync.enabled).disabled(!sync.configured)
            } footer: { Text(L("请在系统选择器中进入 iCloud Drive。也可选择其他文件提供商；如果选择本机文件夹，则只是本地备份。此功能同步结果文件，不同步设置和收藏。工具箱不判断云端上传是否完成。")) }
            if sync.configured {
                Section { Button(L("刷新文件列表"), systemImage: "arrow.clockwise") { Task { await sync.refresh() } }.disabled(sync.busy)
                    if sync.busy { ProgressView(L("读取文件夹…")) }
                    ForEach(sync.files) { file in Button { Task { do { PreviewRouter.shared.open(try await sync.localCopy(file.url)) } catch { self.error = error.localizedDescription } } } label: { Label(file.name, systemImage: "doc") } }
                } header: { Text(L("同步文件夹中的文件")) }
                Section { Button(L("断开连接"), role: .destructive) { sync.disconnect() } }
            }
            if !sync.message.isEmpty { Section { Text(sync.message).font(.footnote).foregroundStyle(.secondary) } }
        }.navigationTitle(L("iCloud 与文件同步"))
            .fileImporter(isPresented: $selecting, allowedContentTypes: [.folder]) { result in do { try sync.choose(result.get()) } catch { self.error = error.localizedDescription } }
            .alert(L("无法访问文件夹"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(error ?? "") }
    }
}
