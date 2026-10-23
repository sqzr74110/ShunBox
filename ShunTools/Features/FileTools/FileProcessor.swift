import Foundation
import PDFKit

actor FileProcessor {
    static let shared = FileProcessor()
    func rename(_ source: URL, name: String) throws -> URL {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains(":"), !name.contains("\\"), name.utf8.count <= 180 else { throw ToolFailure(message: L("请输入有效文件名（不含路径分隔符，最多 180 字节）。")) }
        let target = try FileStore.destination(name + (source.pathExtension.isEmpty ? "" : "." + source.pathExtension))
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }
    func pdf(_ sources: [URL], pages: ClosedRange<Int>?) throws -> URL {
        guard !sources.isEmpty else { throw ToolFailure(message: L("请先选择 PDF。")) }
        let output = PDFDocument()
        for source in sources {
            try Task.checkCancellation()
            guard let document = PDFDocument(url: source), !document.isLocked, document.pageCount > 0 else { throw ToolFailure(message: L("无法读取 PDF，文件可能已加密或损坏。")) }
            let range = pages ?? 1...document.pageCount
            guard range.lowerBound >= 1, range.upperBound <= document.pageCount else { throw ToolFailure(message: L("页码超出范围。此文档共 {0} 页。", String(describing: document.pageCount))) }
            for index in range {
                try Task.checkCancellation()
                guard let page = document.page(at: index - 1) else { throw ToolFailure(message: L("无法读取第 {0} 页。", String(describing: index))) }
                output.insert(page, at: output.pageCount)
            }
        }
        let url = try FileStore.destination(pages == nil ? L("合并文档.pdf") : L("提取页面.pdf"))
        guard output.write(to: url) else { throw ToolFailure(message: L("PDF 写入失败，请检查可用存储空间。")) }
        try Task.checkCancellation()
        return url
    }
}
