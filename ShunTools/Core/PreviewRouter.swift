import SwiftUI
import QuickLook
import PDFKit
import UniformTypeIdentifiers

struct PreviewItem: Identifiable { let url: URL; let id = UUID() }
@MainActor @Observable final class PreviewRouter {
    static let shared = PreviewRouter()
    var item: PreviewItem?
    var error: String?
    func open(_ url: URL) {
        guard FileManager.default.isReadableFile(atPath: url.path) else { error = L("文件已不存在，请重新处理。"); return }
        item = PreviewItem(url: url)
    }
}
struct FilePreviewView: View {
    let item: PreviewItem
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loaded = false
    var body: some View {
        NavigationStack {
            Group {
                if item.url.pathExtension.lowercased() == "pdf" { PDFPreview(url: item.url) }
                else if UTType(filenameExtension: item.url.pathExtension)?.conforms(to: .image) == true {
                    if let image { GeometryReader { proxy in ScrollView { Image(uiImage: image).resizable().scaledToFit().frame(width: proxy.size.width).frame(minHeight: proxy.size.height) } } }
                    else if loaded { ContentUnavailableView(L("无法读取文件"), systemImage: "photo") }
                    else { ProgressView() }
                } else { QuickLookFile(url: item.url) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(item.url.lastPathComponent).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("关闭")) { dismiss() }.accessibilityIdentifier("preview.close") }; ToolbarItem(placement: .topBarLeading) { ShareLink(item: item.url) { Image(systemName: "square.and.arrow.up") } } }
                .task(id: item.id) {
                    if UTType(filenameExtension: item.url.pathExtension)?.conforms(to: .image) == true { image = await ImageProcessor.shared.preview(item.url).flatMap(UIImage.init(data:)); loaded = true }
                }
        }
    }
}
private struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.document = PDFDocument(url: url); return view }
    func updateUIView(_ view: PDFView, context: Context) {}
}
private struct QuickLookFile: UIViewControllerRepresentable {
    let url: URL
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: NSURL
        init(url: URL) { self.url = url as NSURL }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url }
    }
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController { let view = QLPreviewController(); view.dataSource = context.coordinator; return view }
    func updateUIViewController(_ view: QLPreviewController, context: Context) {}
}
