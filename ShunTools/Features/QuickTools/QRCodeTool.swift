import SwiftUI
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

actor QRProcessor {
    static let shared = QRProcessor()
    func generate(_ text: String) throws -> URL {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 1500 else { throw ToolFailure(message: L("请输入 1–1500 字节的文字或链接。")) }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 12, y: 12)), from: output.extent.applying(CGAffineTransform(scaleX: 12, y: 12))) else { throw ToolFailure(message: L("无法生成二维码。")) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let size = CGSize(width: cg.width + 96, height: cg.height + 96)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); context.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(x: 48, y: 48, width: cg.width, height: cg.height))
        }
        let url = try FileStore.destination(L("二维码.png"))
        guard let data = image.pngData() else { throw ToolFailure(message: L("二维码写入失败。")) }; try data.write(to: url); return url
    }
    func recognize(_ url: URL) throws -> [String] {
        guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { throw ToolFailure(message: L("无法读取二维码图片。")) }
        let results = detector.features(in: image).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        try Task.checkCancellation()
        guard !results.isEmpty else { throw ToolFailure(message: L("没有找到可读取的二维码。请使用清晰、完整的图片。")) }
        return results
    }
}
struct QRCodeToolView: View {
    @Environment(LibraryStore.self) private var library
    @State private var text = ""
    @FocusState private var editing: Bool
    @State private var state = OperationState()
    @State private var preview: UIImage?
    @State private var importing = false
    @State private var recognized: [String] = []
    var body: some View {
        Form {
            Section { TextEditor(text: $text).focused($editing).frame(minHeight: 130).accessibilityLabel(L("二维码内容")); LabeledContent(L("UTF-8 字节数"), value: "\(text.utf8.count) / 1500").font(.caption).foregroundStyle(.secondary)
                Button(L("生成二维码"), systemImage: "qrcode") {
                    let content = text; recognized = []; editing = false
                    state.run(archive: true) { let url = try await QRProcessor.shared.generate(content); let data = try Data(contentsOf: url); await MainActor.run { preview = UIImage(data: data) }; return url } success: { library.record(.qr); Task { await AdPolicy.shared.conversionCompleted() } }
                }.buttonStyle(.glassProminent).tint(.brandButton).disabled(state.busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.utf8.count > 1500)
            } header: { Text(L("文字或链接")) } footer: { Text(L("完全离线生成，内容直接编码到图片中。不要放入不想公开的密码或个人信息。")) }
            Section { Button(L("从图片文件识别二维码"), systemImage: "viewfinder") { importing = true }.disabled(state.busy) }
            if let preview { Section { Image(uiImage: preview).resizable().interpolation(.none).scaledToFit().frame(maxWidth: .infinity, maxHeight: 280).accessibilityLabel(L("生成的二维码")) } }
            ForEach(Array(recognized.enumerated()), id: \.offset) { _, value in Section(L("识别内容")) { Text(value).textSelection(.enabled); Button(L("复制内容"), systemImage: "doc.on.doc") { UIPasteboard.general.string = value } } }
            OperationFeedback(state: state)
            if let output = state.output { ResultView(url: output) }
        }.onDisappear { state.cancel() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { selection in
            switch selection { case .success(let source):
                state.run {
                    let url = try await Task.detached { try FileStore.importFile(source) }.value
                    let contents = try await QRProcessor.shared.recognize(url)
                    await MainActor.run { recognized = contents; preview = nil }
                    return url
                } success: { state.output = nil; library.record(.qr); Task { await AdPolicy.shared.conversionCompleted() } }
            case .failure(let error): state.error = error.localizedDescription }
        }
    }
}
