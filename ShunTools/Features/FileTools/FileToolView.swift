import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct FileToolView: View {
    @Environment(LibraryStore.self) private var library
    @State private var state = OperationState()
    @State private var importing = false
    @State private var url: URL?
    @State private var name = ""
    var body: some View {
        Form {
            Section {
                if let url {
                    Label(url.lastPathComponent, systemImage: "doc").font(.headline)
                    LabeledContent(L("大小"), value: FileStore.size(url))
                    LabeledContent(L("类型"), value: UTType(filenameExtension: url.pathExtension)?.localizedDescription ?? L("未知文件"))
                    if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate { LabeledContent(L("修改日期"), value: date.formatted(date: .abbreviated, time: .shortened)) }
                    Button(L("预览文件"), systemImage: "eye") { PreviewRouter.shared.open(url) }
                } else { ContentUnavailableView(L("文件，井井有条"), systemImage: "folder", description: Text(L("查看属性、重命名并导出副本。原始文件保持不变。"))) }
                Button(L("导入文件"), systemImage: "plus") { importing = true }
            }.disabled(state.busy)
            if let url { Section(L("重命名副本")) { TextField(L("文件名（不含扩展名）"), text: $name); Button(L("创建重命名副本"), systemImage: "pencil") {
                let newName = name
                state.run(archive: true) { try await FileProcessor.shared.rename(url, name: newName) } success: { library.record(.files); Task { await AdPolicy.shared.conversionCompleted() } }
            }.disabled(name.isEmpty || state.busy) } }
            OperationFeedback(state: state)
            if let output = state.output, output != url { ResultView(url: output) }
        }
        .onDisappear { state.cancel() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            switch result { case .success(let source): state.run {
                let copied = try await Task.detached { try FileStore.importFile(source) }.value
                await MainActor.run { url = copied; name = copied.deletingPathExtension().lastPathComponent }
                return copied
            } success: { library.record(.files) }
            case .failure(let error): state.error = error.localizedDescription }
        }
    }
}
struct PDFToolView: View {
    @Environment(LibraryStore.self) private var library
    @State private var state = OperationState()
    @State private var urls: [URL] = []
    @State private var importing = false
    @State private var split = false
    @State private var first = 1
    @State private var last = 1
    var body: some View {
        Form {
            Section { Picker(L("操作"), selection: $split) { Text(L("合并 PDF")).tag(false); Text(L("提取页面")).tag(true) }.pickerStyle(.segmented) }.disabled(state.busy)
            Section { if urls.isEmpty { ContentUnavailableView(L("文档，恰如其分"), systemImage: "doc.on.doc", description: Text(L("合并多个 PDF，或将指定页面拆分为新文件。"))) }
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    HStack { Button { PreviewRouter.shared.open(url) } label: { VStack(alignment: .leading) { Text("\(index + 1). \(url.lastPathComponent)"); Text(FileStore.size(url)).font(.caption).foregroundStyle(.secondary) } }; Spacer(); if index > 0 { Button { urls.swapAt(index, index - 1); state.output = nil } label: { Image(systemName: "arrow.up") }.buttonStyle(.borderless).accessibilityLabel(L("上移文件")) }; Button(role: .destructive) { urls.remove(at: index); state.output = nil } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel(L("移除文件")) }
                }
                Button(L("添加 PDF"), systemImage: "plus") { importing = true }
            } header: { Text(L("输入文档")) } footer: { Text(split ? L("提取页面仅使用列表中的第一份文档。") : L("按照列表从上到下合并。点击箭头调整顺序。")) }.disabled(state.busy)
            if split { Section(L("页码范围（从 1 开始）")) { LabeledContent(L("起始页")) { TextField("1", value: $first, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }; LabeledContent(L("结束页")) { TextField("1", value: $last, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) } }.disabled(state.busy) }
            Section { Button(split ? L("提取并生成 PDF") : L("合并 PDF"), systemImage: "doc.badge.plus") {
                guard !split || (first > 0 && last >= first) else { state.error = L("请输入有效页码范围。"); return }
                let sources = split ? Array(urls.prefix(1)) : urls, range = split ? first...last : nil
                state.run(archive: true) { try await FileProcessor.shared.pdf(sources, pages: range) } success: { library.record(.pdf); Task { await AdPolicy.shared.conversionCompleted() } }
            }.buttonStyle(.glassProminent).tint(.brandButton).disabled(urls.isEmpty || state.busy) }
            OperationFeedback(state: state)
            if let output = state.output { ResultView(url: output) }
        }.onDisappear { state.cancel() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                switch result { case .success(let selected):
                    state.run {
                        let copied = try await Task.detached { try selected.map(FileStore.importFile) }.value
                        await MainActor.run { urls.append(contentsOf: copied) }
                        guard let first = copied.first else { throw CancellationError() }; return first
                    } success: { state.output = nil }
                case .failure(let error): state.error = error.localizedDescription }
            }
    }
}
