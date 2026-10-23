import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct ImageToolView: View {
    var initialFormat: String? = nil
    @Environment(LibraryStore.self) private var library
    @AppStorage("imageFormat") private var preferredFormat = "jpeg"
    @State private var selection: [PhotosPickerItem] = []
    @State private var urls: [URL] = []
    @State private var preview: UIImage?
    @State private var styledPreview: UIImage?
    @State private var metadata = PhotoMetadata()
    @State private var importing = false
    @State private var options = ImageOptions()
    @State private var state = OperationState()
    @State private var results: [URL] = []
    @State private var notice: String?
    var body: some View {
        Form {
            Section {
                if let visiblePreview = styledPreview ?? preview { Image(uiImage: visiblePreview).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 240).accessibilityLabel(L("所选图片预览")) }
                else { ContentUnavailableView(L("从一张照片开始"), systemImage: "photo.badge.plus", description: Text(L("转换格式、缩小体积，或抹去位置痕迹。"))) }
                PhotosPicker(selection: $selection, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) { Label(L("从照片选择"), systemImage: "photo") }
                Button(L("从文件选择"), systemImage: "folder") { importing = true }
                if !urls.isEmpty { Text(L("已选择 {0} 张 · 首张 {1}", String(describing: urls.count), String(describing: FileStore.size(urls[0])))).font(.caption).foregroundStyle(.secondary) }
            }.disabled(state.busy)
            Section {
                Button(L("一键添加相机水印"), systemImage: "camera.aperture") { options.watermarkStyle = .glassFooter; options.showCamera = true; options.showSettings = true }
                    .buttonStyle(.bordered).tint(.indigo).disabled(urls.isEmpty)
                Picker(L("水印模板"), selection: $options.watermarkStyle) { ForEach(WatermarkStyle.allCases, id: \.self) { Text($0.title).tag($0) } }
                if options.watermarkStyle != .none {
                    TextField(L("署名或标题（可选）"), text: $options.watermark).onChange(of: options.watermark) { _, value in options.watermark = String(value.prefix(60)) }
                    if options.watermarkStyle == .text && options.watermark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(L("未填写署名时显示 SHUNBOX，可在上方自定义。")).font(.caption).foregroundStyle(.secondary) }
                    if options.watermarkStyle != .text {
                        Toggle(L("显示相机型号"), isOn: $options.showCamera)
                        Toggle(L("显示拍摄参数"), isOn: $options.showSettings)
                        Toggle(L("显示拍摄日期"), isOn: $options.showDate)
                        if !urls.isEmpty { Text(metadata.camera.isEmpty && metadata.settings.isEmpty ? L("这张图片没有相机参数；不会添加虚构参数。") : [metadata.camera, metadata.settings].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            } header: { Text(L("摄影水印")) } footer: { Text(L("模板效果显示在上方预览。参数来自每张原图，缺失项自动略过。显示到水印中的机型或日期会成为图片内容；不会添加定位。边框会增加输出高度。")) }.disabled(state.busy)
            Section(L("按用途一键设置")) {
                ScrollView(.horizontal, showsIndicators: false) { HStack {
                    Button(L("通用 JPG")) { options.format = "jpeg"; options.quality = 0.9; options.targetBytes = 0 }.buttonStyle(.glass)
                    Button(L("上传 ≤ 1 MB")) { options.format = "jpeg"; options.maxDimension = 2400; options.targetBytes = 1_000_000 }.buttonStyle(.glass)
                    Button(L("小图 ≤ 200 KB")) { options.format = "jpeg"; options.maxDimension = 1280; options.targetBytes = 200_000 }.buttonStyle(.glass)
                }.padding(.vertical, 4) }
            }.disabled(state.busy)
            Section(L("输出设置")) {
                Picker(L("格式"), selection: $options.format) { ForEach(ImageFormat.available) { Text($0.title).tag($0.id) }; Text(L("PDF · 多图合集")).tag("pdf") }
                if ["jpeg", "heic", "pdf", "webp"].contains(options.format) { VStack(alignment: .leading) { LabeledContent(L("质量"), value: options.quality.formatted(.percent.precision(.fractionLength(0)))); Slider(value: $options.quality, in: 0.1...1) } }
                Picker(L("目标体积"), selection: $options.targetBytes) { Text(L("不限制")).tag(0); Text("200 KB").tag(200_000); Text("1 MB").tag(1_000_000); Text("2 MB").tag(2_000_000) }.disabled(options.format == "pdf")
                if options.targetBytes > 0 && options.format != "pdf" { Text(L("必要时会继续降低质量和尺寸，直到实际文件达到目标。上方预览仅显示样式，最终清晰度请检查导出结果。")).font(.caption).foregroundStyle(.secondary) }
                Picker(L("最长边"), selection: $options.maxDimension) { ForEach([640, 1280, 1920, 2400, 3840, 8192], id: \.self) { Text(L("{0} 像素", String(describing: $0))).tag($0) } }

            }.disabled(state.busy)
            Section { Label(L("自动移除 EXIF 与位置信息"), systemImage: "location.slash").foregroundStyle(.blue) } footer: { Text(L("所有输出均重新编码并移除原始元数据；图片不会放大。JPG 的透明区域转为白色，输出采用标准动态范围。动图仅处理首帧。GIF 输出也是静态图片；格式列表根据本机编码器能力显示。")) }
            Section { Button { process() } label: { Label(urls.count > 1 ? L("处理 {0} 张图片", String(describing: urls.count)) : L("处理图片"), systemImage: "sparkles").frame(maxWidth: .infinity).padding(.vertical, 6) }.buttonStyle(.glassProminent).tint(.brandButton).disabled(urls.isEmpty || state.busy) }
            OperationFeedback(state: state)
            ForEach(results, id: \.self) { url in ResultView(url: url) }
            if !results.isEmpty && results.first?.pathExtension != "pdf" { Section { Button(L("保存全部到相册"), systemImage: "photo.badge.arrow.down") { savePhotos() }.disabled(state.busy) } }
        }
        .onAppear { options.format = initialFormat ?? preferredFormat }
        .task(id: PreviewRequest(url: urls.first, options: options)) {
            guard let url = urls.first else { styledPreview = nil; return }
            metadata = await ImageProcessor.shared.metadata(url)
            do { let data = try await ImageProcessor.shared.renderPreview(url, options: options); try Task.checkCancellation(); styledPreview = data.flatMap(UIImage.init(data:)) } catch is CancellationError {} catch { state.error = error.localizedDescription }
        }
        .onDisappear { state.cancel() }
        .onChange(of: selection) { _, items in
            state.run {
                var imported: [URL] = []
                for item in items {
                    try Task.checkCancellation()
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw ToolFailure(message: L("无法从照片读取图片。")) }
                    let url = try FileStore.destination(L("照片-{0}.", String(describing: imported.count + 1)) + (item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg")); try data.write(to: url); imported.append(url)
                }
                guard let first = imported.first else { throw CancellationError() }
                let thumbnail = await ImageProcessor.shared.preview(first)
                let completed = imported
                await MainActor.run { urls = completed; preview = thumbnail.flatMap(UIImage.init(data:)); results = [] }
                return first
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result { case .success(let selected):
                state.run {
                    let imported = try await Task.detached { try selected.prefix(20).map(FileStore.importFile) }.value
                    guard let first = imported.first else { throw CancellationError() }
                    let thumbnail = await ImageProcessor.shared.preview(first)
                    await MainActor.run { urls = imported; preview = thumbnail.flatMap(UIImage.init(data:)); results = [] }
                    return first
                }
            case .failure(let error): state.error = error.localizedDescription }
        }
        .alert(L("照片"), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button(L("好"), role: .cancel) {} } message: { Text(notice ?? "") }
    }
    private func process() {
        let input = urls, configuration = options; results = []
        state.run {
            let processed = try await ImageProcessor.shared.process(input, options: configuration)
            var output: [URL] = []
            for url in processed { output.append(try await MediaArchive.shared.save(url)) }
            try Task.checkCancellation()
            let completed = output
            await MainActor.run { results = completed }
            return output[0]
        } success: { library.record(configuration.format == "pdf" ? .imagePDF : .image); Task { await AdPolicy.shared.conversionCompleted() } }
    }
    private func savePhotos() {
        let output = results
        state.run {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { throw ToolFailure(message: L("未获得保存照片权限，请在系统设置中允许添加照片。")) }
            try await PHPhotoLibrary.shared().performChanges { for url in output { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) } }
            await MainActor.run { notice = L("已保存 {0} 张图片到相册。", String(describing: output.count)) }
            return output[0]
        }
    }
}

private struct PreviewRequest: Hashable { let url: URL?; let options: ImageOptions }
