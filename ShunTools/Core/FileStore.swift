import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct ToolFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
enum FileStore {
    static var root: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ShunTools", isDirectory: true) }
    static func destination(_ name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", name == (name as NSString).lastPathComponent, !name.contains("\\") else {
            throw ToolFailure(message: L("请输入有效文件名（不含路径分隔符，最多 180 字节）。"))
        }
        let dir = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
    static func importFile(_ url: URL) throws -> URL {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let target = try destination(url.lastPathComponent)
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
            do { try FileManager.default.copyItem(at: source, to: target) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError as NSError? { throw error }
        return target
    }
    static func size(_ url: URL) -> String { ByteCountFormatter.string(fromByteCount: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0), countStyle: .file) }
    static func clean() throws { if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) } }
    static func prune() { // Keep current session exports; remove abandoned files after one day.
        for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
            if let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate, date.timeIntervalSinceNow < -86400 { try? FileManager.default.removeItem(at: url) }
        }
    }
}
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { throw ToolFailure(message: L("此文档仅用于导出。")) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { try FileWrapper(url: url, options: .immediate) }
}
struct ResultView: View {
    let url: URL
    @State private var exporting = false
    @State private var error: String?
    var body: some View {
        Section {
            Label(L("处理完成"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            LabeledContent(url.lastPathComponent, value: FileStore.size(url))
            Button(L("预览结果"), systemImage: "eye") { PreviewRouter.shared.open(url) }
            Button(L("保存到文件"), systemImage: "square.and.arrow.down") { exporting = true }
            if DocumentSync.shared.configured {
                Button(L("保存到同步文件夹"), systemImage: "icloud.and.arrow.up") { Task { await DocumentSync.shared.save(url) } }
                if !DocumentSync.shared.message.isEmpty { Text(DocumentSync.shared.message).font(.caption).foregroundStyle(.secondary) }
            }
            ShareLink(item: url) { Label(L("分享结果"), systemImage: "square.and.arrow.up") }
        } header: { Text(L("结果")) } footer: { Text(L("处理结果可在媒体库中再次查看、分享。")) }
        
        .task(id: url) { await DocumentSync.shared.save(url, automatic: true) }
        .fileExporter(isPresented: $exporting, document: ExportDocument(url: url), contentType: UTType(filenameExtension: url.pathExtension) ?? .data, defaultFilename: url.lastPathComponent) { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
        .alert(L("无法导出"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(error ?? "") }
    }
}
@MainActor @Observable final class ActivityState {
    static let shared = ActivityState()
    var count = 0
}
@MainActor @Observable final class OperationState {
    var busy = false
    var error: String?
    var output: URL?
    var task: Task<Void, Never>?
    func run(archive: Bool = false, _ work: @escaping @Sendable () async throws -> URL, success: @escaping @MainActor () -> Void = {}) {
        guard !busy else { return }; busy = true; ActivityState.shared.count += 1; output = nil; error = nil
        task = Task {
            do { let result = try await work(); try Task.checkCancellation(); output = archive ? try await MediaArchive.shared.save(result) : result; success() }
            catch is CancellationError {} catch { self.error = error.localizedDescription }
            busy = false; ActivityState.shared.count -= 1
        }
    }
    func cancel() { task?.cancel() }
}
struct OperationFeedback: View {
    @Bindable var state: OperationState
    var body: some View {
        if state.busy { Section { HStack { ProgressView(); Text(L("正在本机处理…")); Spacer(); Button(L("取消"), role: .cancel) { state.cancel() } } } }
        if let error = state.error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
    }
}
