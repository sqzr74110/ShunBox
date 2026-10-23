import SwiftUI
import AVFoundation
import UIKit

struct DeviceInfoView: View {
    @State private var refreshed = Date()
    @State private var screen: UIScreen?
    private var model: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var info = utsname(); uname(&info)
        return withUnsafePointer(to: &info.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
        #endif
    }
    private var storage: [FileAttributeKey: Any] { (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())) ?? [:] }
    private func bytes(_ value: Any?) -> String { guard let value = value as? NSNumber else { return L("不可用") }; return ByteCountFormatter.string(fromByteCount: value.int64Value, countStyle: .file) }
    var body: some View {
        List {
            Section(L("设备")) {
                LabeledContent(L("设备类型"), value: UIDevice.current.localizedModel)
                LabeledContent(L("硬件标识"), value: model)
                LabeledContent(L("系统版本"), value: UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
                #if targetEnvironment(simulator)
                Text(L("当前为模拟器，电池与硬件数据不能用于验机。")).foregroundStyle(.secondary)
                #else
                LabeledContent(L("物理内存"), value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
                #endif
            }
            Section(L("屏幕")) {
                LabeledContent(L("像素尺寸"), value: "\(Int(screen?.nativeBounds.width ?? 0)) × \(Int(screen?.nativeBounds.height ?? 0))")
                LabeledContent(L("显示缩放"), value: "\((screen?.scale ?? 1).formatted())×")
                LabeledContent(L("最高刷新率"), value: "\(screen?.maximumFramesPerSecond ?? 0) Hz")
                Text(L("最高刷新率是屏幕声明的上限，并非实时帧率。")).font(.footnote).foregroundStyle(.secondary)
            }
            Section(L("电池与存储")) {
                LabeledContent(L("当前电量"), value: UIDevice.current.batteryLevel < 0 ? L("不可用") : "\(Int(UIDevice.current.batteryLevel * 100))%")
                LabeledContent(L("低电量模式"), value: ProcessInfo.processInfo.isLowPowerModeEnabled ? L("已开启") : L("已关闭"))
                LabeledContent(L("文件系统总空间"), value: bytes(storage[.systemSize]))
                LabeledContent(L("文件系统剩余空间"), value: bytes(storage[.systemFreeSize]))
                Text(L("空间读数来自应用所在文件系统，不代表包装标称容量。此页面不读取电池健康度或循环次数。")).font(.footnote).foregroundStyle(.secondary)
            }
            Section(L("进一步检查")) {
                NavigationLink(L("设备自检")) { DeviceCheckView().navigationTitle(L("设备自检")) }
                Text(L("序列号、IMEI、保修及零件维修记录，请在系统设置 → 通用 → 关于本机查看；电池健康请在系统设置 → 电池中查看。"))
                Link(L("Apple 官方：零件与维修历史"), destination: URL(string: "https://support.apple.com/102658")!)
                Text(L("本应用不提供原装鉴定、拆修判定、激活锁查询或刷机服务。")).font(.footnote).foregroundStyle(.secondary)
            }
            Section { Button(L("刷新")) { refreshed = Date() }; Text(refreshed, style: .time).foregroundStyle(.secondary) }
        }.background(ScreenContext { screen = $0 }.frame(width: 0, height: 0))
            .onAppear { UIDevice.current.isBatteryMonitoringEnabled = true }
    }
}

@MainActor @Observable final class DeviceAudio {
    var recording = false
    var message = ""
    var hasRecording = false
    var levels: [Float] = []
    var decibels: Float = -80
    var peak: Float = -80
    var elapsed: Double = 0
    private var meter: Task<Void, Never>?
    var signalStatus: String { if peak > -1 { return L("音量过高，可能失真") }; if decibels < -45 { return L("声音较轻，请靠近麦克风") }; return L("正在接收声音") }
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timeout: Task<Void, Never>?
    private var request: Task<Void, Never>?
    private var file: URL?
    func record() {
        stop(); message = ""; levels = []; decibels = -80; peak = -80; elapsed = 0; hasRecording = false
        request = Task {
            guard await AVAudioApplication.requestRecordPermission() else { message = L("未获得麦克风权限，请在系统设置中允许访问。"); return }
            guard !Task.isCancelled else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
                let url = try FileStore.destination("microphone.m4a")
                let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
                recorder.isMeteringEnabled = true
                guard recorder.record(forDuration: 5) else { throw CocoaError(.fileWriteUnknown) }
                self.recorder = recorder; self.file = url; self.recording = true; self.hasRecording = false
                meter = Task {
                    while !Task.isCancelled && self.recording {
                        recorder.updateMeters(); self.decibels = recorder.averagePower(forChannel: 0); self.peak = recorder.peakPower(forChannel: 0); self.elapsed = recorder.currentTime
                        self.levels.append(pow(10, self.decibels / 40)); self.levels = Array(self.levels.suffix(100))
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                }
                timeout = Task { try? await Task.sleep(for: .seconds(5.2)); guard !Task.isCancelled else { return }; finishRecording() }
            } catch { message = error.localizedDescription; stop() }
        }
    }
    func finishRecording() { timeout?.cancel(); meter?.cancel(); recorder?.stop(); recording = false; hasRecording = file.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
    func playRecording() { finishRecording(); guard let file else { return }; play(file) }
    private func play(_ url: URL) {
        do {
            let session = AVAudioSession.sharedInstance(); try session.setCategory(.playback); try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url); player?.volume = 0.35; player?.play()
        } catch { message = error.localizedDescription }
    }
    func tone() {
        stop()
        do {
            let url = try FileStore.destination("speaker.caf")
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200)!
            buffer.frameLength = 88200
            for index in 0..<88200 {
                let envelope = min(1, Double(index)/2205, Double(88199-index)/2205)
                let value = Float(sin(Double(index) * 2 * .pi * 440 / 44100) * 0.3 * envelope)
                for channel in 0..<2 { buffer.floatChannelData![channel][index] = value }
            }
            do { let audio = try AVAudioFile(forWriting: url, settings: format.settings); try audio.write(from: buffer) }
            play(url)
        } catch { message = error.localizedDescription }
    }
    func stop() { request?.cancel(); timeout?.cancel(); meter?.cancel(); if recording { finishRecording() }; player?.stop(); recording = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    func cleanup() { stop(); if let file { try? FileManager.default.removeItem(at: file) }; file = nil; hasRecording = false }
}

struct DeviceCheckView: View {
    @State private var audio = DeviceAudio()
    @State private var showColors = false
    @State private var torchOn = false
    @State private var torchMessage = ""
    @State private var results: [String: String] = [:]
    @Environment(\.scenePhase) private var scenePhase
    private let checks = [L("屏幕显示"), L("触控"), L("扬声器"), L("麦克风"), L("触感"), L("闪光灯")]
    var body: some View {
        List {
            Section { Text(L("按步骤观察与试听，再手动记录结果。自检记录不是硬件鉴定报告，不能判断是否原装或拆修。")).foregroundStyle(.secondary) }
            Section(L("屏幕与触控")) {
                Button(L("全屏纯色检查")) { showColors = true }
                NavigationLink(L("触控覆盖测试")) { TouchCheckView() }
            }
            Section(L("声音与触感")) {
                Button(L("播放测试音（2 秒）")) { audio.tone() }
                Text(L("先调低系统音量。播放路径可能是已连接的耳机，请确认声音输出位置。")).font(.footnote).foregroundStyle(.secondary)
                Button(audio.recording ? L("停止录音") : L("录制麦克风（5 秒）")) { if audio.recording { audio.finishRecording() } else { audio.record() } }
                if audio.recording || !audio.levels.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Label(audio.recording ? L("录音中…") : L("录音完成"), systemImage: audio.recording ? "record.circle" : "checkmark.circle").foregroundStyle(audio.recording ? .red : .secondary); Spacer(); Text("\(audio.elapsed, specifier: "%.1f") / 5 s").monospacedDigit() }
                        Canvas { context, size in
                            let width = size.width / 100
                            for (index, level) in audio.levels.enumerated() {
                                let height = max(3, CGFloat(level) * size.height)
                                let rect = CGRect(x: CGFloat(index) * width, y: (size.height - height) / 2, width: max(1, width - 2), height: height)
                                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .linearGradient(Gradient(colors: [.indigo, .pink]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                            }
                        }.frame(height: 72).accessibilityLabel(L("实时声音波形"))
                        HStack { Text(audio.signalStatus); Spacer(); Text("\(audio.decibels, specifier: "%.0f") dBFS").monospacedDigit() }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Text(L("波形与电平反映录音强弱，不识别身份，也不代表硬件鉴定结果。")).font(.caption).foregroundStyle(.secondary)
                Button(L("回放录音")) { audio.playRecording() }.disabled(!audio.hasRecording)
                Button(L("停止声音")) { audio.stop() }
                Button(L("测试触感")) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                if !audio.message.isEmpty { Text(audio.message).foregroundStyle(.secondary) }
            }
            Section(L("闪光灯")) {
                Button(torchOn ? L("关闭闪光灯") : L("开启闪光灯")) { setTorch(!torchOn) }
                if !torchMessage.isEmpty { Text(torchMessage).foregroundStyle(.secondary) }
            }
            Section(L("手动记录")) {
                ForEach(checks, id: \.self) { key in
                    Picker(key, selection: Binding(get: { results[key] ?? L("未测试") }, set: { results[key] = $0 })) {
                        Text(L("未测试")).tag(L("未测试")); Text(L("观察正常")).tag(L("观察正常")); Text(L("发现异常")).tag(L("发现异常"))
                    }
                }
                Text(L("记录仅保留在当前页面。没有自动判定通过的项目。")).font(.footnote).foregroundStyle(.secondary)
            }
        }.fullScreenCover(isPresented: $showColors) { ScreenCheckView() }
            .onDisappear { audio.cleanup(); setTorch(false) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop(); setTorch(false) } }
    }
    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { if on { torchMessage = L("此设备没有可用闪光灯。") }; return }
        do { try device.lockForConfiguration(); defer { device.unlockForConfiguration() }; if on { try device.setTorchModeOn(level: 0.2) } else { device.torchMode = .off }; torchOn = on }
        catch { torchMessage = error.localizedDescription }
    }
}

struct ScreenCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    private let colors: [Color] = [.white, .black, .red, .green, .blue, .gray]
    var body: some View {
        colors[index].ignoresSafeArea().overlay(alignment: .bottom) {
            HStack { Button(L("关闭")) { dismiss() }; Spacer(); Button(L("下一种颜色")) { index = (index+1)%colors.count } }
                .buttonStyle(.glass).padding().foregroundStyle(index == 1 ? .white : .black)
        }.statusBarHidden().persistentSystemOverlays(.hidden)
    }
}
struct TouchCheckView: View {
    @State private var visited: Set<Int> = []
    var body: some View {
        VStack {
            Text(L("用手指划过每个方格，观察是否有无法触达的区域。此测试仅检查当前区域。")).padding()
            GeometryReader { proxy in
                ZStack {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6), spacing: 2) {
                        ForEach(0..<60) { index in Rectangle().fill(visited.contains(index) ? Color.accentColor : Color.secondary.opacity(0.15)).frame(height: max(1, (proxy.size.height-18)/10)) }
                    }
                    Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let x = Int(value.location.x / max(1, proxy.size.width) * 6), y = Int(value.location.y / max(1, proxy.size.height) * 10)
                        if (0..<6).contains(x), (0..<10).contains(y) { visited.insert(y*6+x) }
                    })
                }
            }.padding(.horizontal)
            Text(L("已覆盖 {0} / 60 格", String(describing: visited.count))).monospacedDigit().padding()
            Button(L("重置")) { visited.removeAll() }.buttonStyle(.glass).padding(.bottom)
        }.navigationTitle(L("触控覆盖测试"))
    }
}

private struct ScreenContext: UIViewRepresentable {
    var changed: (UIScreen) -> Void
    final class Probe: UIView {
        var changed: ((UIScreen) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let screen = window?.windowScene?.screen { DispatchQueue.main.async { [weak self] in self?.changed?(screen) } }
        }
    }
    func makeUIView(context: Context) -> Probe { let view = Probe(); view.changed = changed; return view }
    func updateUIView(_ uiView: Probe, context: Context) { uiView.changed = changed }
}
