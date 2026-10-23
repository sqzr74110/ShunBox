import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Combine
import PhotosUI
import CoreTransferable

struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) } importing: { received in
            let target = try FileStore.destination(L("视频声音.mov"))
            try FileManager.default.copyItem(at: received.file, to: target)
            return ImportedMovie(url: target)
        }
    }
}
struct AudioToolView: View {
    let ringtone: Bool
    var videoMode = false
    @Environment(LibraryStore.self) private var library
    @State private var state = OperationState()
    @State private var importing = false
    @State private var movie: PhotosPickerItem?
    @State private var url: URL?
    @State private var duration = 0.0
    @State private var start = 0.0
    @State private var end = 1.0
    @State private var fade = 0.0
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var selectionPlayback = false
    @State private var loop = true
    @State private var position = 0.0
    @State private var peaks: [Float] = []
    @State private var result: URL?
    @State private var format = "m4a"
    @State private var outputName = L("我的声音")
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    var body: some View {
        Form {
            inputSection
            if url != nil {
                selectionSection
                Section(L("导出设置")) {
                    TextField(L("声音名称"), text: $outputName).onChange(of: outputName) { _, value in outputName = String(value.prefix(50)) }
                    Picker(L("格式"), selection: $format) {
                        Text(L("M4A · 推荐铃声 / 分享")).tag("m4a")
                        Text(L("M4R · 铃声兼容格式")).tag("m4r")
                        if !ringtone { Text("WAV · PCM").tag("wav"); Text("AIFF · PCM").tag("aiff"); Text("CAF · PCM").tag("caf") }
                    }
                    Picker(L("淡入与淡出"), selection: $fade) { Text(L("关闭")).tag(0.0); Text(L("0.1 秒 · 提示音")).tag(0.1); Text(L("0.5 秒")).tag(0.5); Text(L("1 秒")).tag(1.0); Text(L("2 秒")).tag(2.0) }
                }.disabled(state.busy)
                Section {
                    Button(L("制作并导出声音"), systemImage: "waveform.badge.plus") { export() }.buttonStyle(.glassProminent).tint(.brandButton)
                        .disabled(state.busy || end <= start || ((ringtone || format == "m4r") && end - start > 30) || outputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: { Text(ringtone || format == "m4r" ? L("铃声最长 30 秒。推荐 29 秒来电铃声，或 3–5 秒短提示音。") : L("M4A 体积较小；WAV / AIFF / CAF 使用 44.1 kHz、16 位、双声道 PCM，体积较大。不会恢复源文件已经损失的音质。")) }
            }
            OperationFeedback(state: state)
            if let result {
                ResultView(url: result)
                Section { Button(L("试听导出结果"), systemImage: "play.circle") { do { player?.stop(); player = try AVAudioPlayer(contentsOf: result); selectionPlayback = false; try activatePlayback(); player?.play() } catch { state.error = error.localizedDescription } } }
            }
            if ringtone || format == "m4r" { ringtoneHelp }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio, .movie]) { selection in
            switch selection { case .success(let source):
                state.run {
                    let imported = try await Task.detached { try FileStore.importFile(source) }.value
                    return try await load(imported)
                }
            case .failure(let error): state.error = error.localizedDescription }
        }
        .onChange(of: movie) { _, item in
            guard let item else { return }
            state.run {
                guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else { throw ToolFailure(message: L("无法读取视频，请重试或从文件导入。")) }
                return try await load(movie.url)
            }
        }
        .onReceive(timer) { _ in tick() }
        .onDisappear { player?.stop(); selectionPlayback = false; state.cancel(); try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    private var inputSection: some View {
        Section {
            if let url {
                Label(url.lastPathComponent, systemImage: "waveform").font(.headline)
                LabeledContent(L("音频信息"), value: L("{0} 秒 · {1} · {2}", String(describing: duration.formatted(.number.precision(.fractionLength(1)))), String(describing: FileStore.size(url)), String(describing: url.pathExtension.uppercased())))
                Slider(value: $position, in: 0...max(duration, 0.01)) { editing in if !editing { player?.currentTime = position } }.accessibilityLabel(L("播放位置"))
                Button(playing ? L("暂停") : L("播放原音频"), systemImage: playing ? "pause.fill" : "play.fill") {
                    if playing { player?.pause(); playing = false; selectionPlayback = false } else { playSelection(false) }
                }
            } else { ContentUnavailableView(ringtone ? L("把喜欢的声音，设为日常") : videoMode ? L("让视频里的声音独立出来") : L("留住喜欢的声音"), systemImage: ringtone ? "bell.badge.waveform" : "waveform", description: Text(L("选一个音频或视频，拖动波形两侧选段。"))) }
            Button(L("从文件导入音频 / 视频"), systemImage: "folder") { importing = true }
            PhotosPicker(selection: $movie, matching: .videos, preferredItemEncoding: .current) { Label(L("从相册提取视频声音"), systemImage: "video") }
        }.disabled(state.busy)
    }
    private var selectionSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) { HStack {
                preset(L("提示音 3s"), seconds: 3); preset(L("提示音 5s"), seconds: 5); preset(L("短铃声 10s"), seconds: 10); preset(L("来电 29s"), seconds: 29)
            }.padding(.vertical, 4) }
            if !peaks.isEmpty { WaveformView(peaks: peaks, duration: duration, start: $start, end: $end) }
            VStack(alignment: .leading) { Text(L("开始：{0} 秒", String(describing: start.formatted(.number.precision(.fractionLength(2)))))); Slider(value: $start, in: 0...max(duration - 0.1, 0.01), step: 0.01).accessibilityLabel(L("开始时间")) }
            VStack(alignment: .leading) { Text(L("结束：{0} 秒", String(describing: end.formatted(.number.precision(.fractionLength(2)))))); Slider(value: $end, in: 0.01...max(duration, 0.01), step: 0.01).accessibilityLabel(L("结束时间")) }
            HStack { Button(L("当前位置设为开始")) { start = min(position, max(0, end - 0.1)) }; Spacer(); Button(L("设为结束")) { end = max(start + 0.1, min(duration, position)) } }.font(.subheadline)
            LabeledContent(L("片段时长"), value: L("{0} 秒", String(describing: max(0, end - start).formatted(.number.precision(.fractionLength(2))))))
            Toggle(L("循环试听片段"), isOn: $loop)
            Button(L("试听所选片段"), systemImage: "play.rectangle") { playSelection(true) }.buttonStyle(.glass).disabled(end <= start)
        } header: { Text(L("拖动选段，或一键选择长度")) } footer: { Text(L("波形来自实际音频。导出结果可再次试听，确认淡入淡出效果。")) }.disabled(state.busy)
    }
    private var ringtoneHelp: some View {
        Section(L("设为铃声 / 提示音")) {
            Text(L("1. 推荐导出 30 秒以内的 M4A。\n2. 点击分享，查看系统是否提供“用作铃声”；也可先保存到文件，再从文件 App 分享。\n3. 在系统设置 → 声音与触感中，选择已添加的声音。具体提示音可选项由系统和对应 App 决定。"))
            Text(L("如果系统未显示该选项，可将 M4A 导入 GarageBand，分享 → 铃声 → 导出。工具箱只制作与分享文件，最终安装由系统完成。")) .font(.footnote).foregroundStyle(.secondary)
            Link(L("Apple 官方：使用 GarageBand 制作铃声"), destination: URL(string: "https://support.apple.com/zh-cn/120692")!)
        }
    }
    private func preset(_ title: String, seconds: Double) -> some View {
        Button(title) { start = min(start, max(0, duration - seconds)); end = min(duration, start + seconds); fade = seconds <= 5 ? 0.1 : 0.5; format = "m4a" }.buttonStyle(.glass)
    }
    private func load(_ imported: URL) async throws -> URL {
        let audio = try await AudioProcessor.shared.prepare(imported)
        let info = try await AudioProcessor.shared.inspect(audio)
        let waveform = try await AudioProcessor.shared.waveform(audio)
        try Task.checkCancellation()
        try await MainActor.run {
            player?.stop(); player = try AVAudioPlayer(contentsOf: audio); playing = false; position = 0; result = nil
            url = audio; duration = info.duration; start = 0; end = ringtone ? min(29, info.duration) : info.duration; peaks = waveform
            outputName = ringtone ? L("我的铃声") : L("我的声音")
        }
        return audio
    }
    private func activatePlayback() throws { try AVAudioSession.sharedInstance().setCategory(.playback); try AVAudioSession.sharedInstance().setActive(true) }
    private func playSelection(_ selected: Bool) {
        guard let url else { return }
        do {
            player?.stop(); player = try AVAudioPlayer(contentsOf: url); try activatePlayback(); selectionPlayback = selected
            player?.currentTime = selected ? start : min(position, duration); player?.volume = 1; player?.play(); playing = true
        } catch { state.error = error.localizedDescription }
    }
    private func tick() {
        guard let player else { return }; playing = player.isPlaying
        if selectionPlayback && loop && !playing && position >= end - 0.15 { player.currentTime = start; player.play(); playing = true }
        if playing {
            position = player.currentTime
            if selectionPlayback {
                if position >= end { if loop { player.currentTime = start } else { player.pause(); playing = false; selectionPlayback = false } }
                let ramp = min(fade, max(0, end - start) / 2)
                player.volume = ramp > 0 ? Float(max(0, min(1, (player.currentTime - start) / ramp, (end - player.currentTime) / ramp))) : 1
            }
        }
    }
    private func export() {
        guard let url else { return }; player?.pause(); playing = false; selectionPlayback = false; result = nil
        let from = start, to = end, fading = fade, selectedFormat = format, name = outputName
        state.run(archive: true) {
            let output = try await AudioProcessor.shared.export(url, start: from, end: to, fade: fading, ringtone: selectedFormat == "m4r", format: selectedFormat)
            let renamed = try await FileProcessor.shared.rename(output, name: name)
            try? FileManager.default.removeItem(at: output)
            try Task.checkCancellation(); await MainActor.run { result = renamed }; return renamed
        } success: { library.record(videoMode ? .videoAudio : ringtone ? .ringtone : .audio); Task { await AdPolicy.shared.conversionCompleted() } }
    }
}
