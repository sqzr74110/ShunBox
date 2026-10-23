import AVFoundation
import UniformTypeIdentifiers

struct AudioInfo: Sendable { let duration: Double }
actor AudioProcessor {
    static let shared = AudioProcessor()
    func inspect(_ url: URL) async throws -> AudioInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, try await !asset.loadTracks(withMediaType: .audio).isEmpty else { throw ToolFailure(message: L("无法读取有效音轨，文件可能损坏或格式不受支持。")) }
        return AudioInfo(duration: duration)
    }
    func export(_ url: URL, start: Double, end: Double, fade: Double, ringtone: Bool, format: String = "m4a") async throws -> URL {
        guard start >= 0, end > start, !ringtone || end - start <= 30.01 else { throw ToolFailure(message: L("请检查裁剪区间；铃声长度不能超过 30 秒。")) }
        let asset = AVURLAsset(url: url)
        guard let source = try await asset.loadTracks(withMediaType: .audio).first else { throw ToolFailure(message: L("文件中没有可导出的音轨。")) }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw ToolFailure(message: L("无法创建音频轨道。")) }
        let length = end - start
        try track.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: length, preferredTimescale: 600)), of: source, at: .zero)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { throw ToolFailure(message: L("此音频不支持 M4A 导出。")) }
        var audioMix: AVMutableAudioMix?
        if fade > 0 {
            let duration = min(fade, length / 2)
            let parameter = AVMutableAudioMixInputParameters(track: track)
            parameter.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600)))
            parameter.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: length - duration, preferredTimescale: 600), duration: CMTime(seconds: duration, preferredTimescale: 600)))
            let mix = AVMutableAudioMix(); mix.inputParameters = [parameter]; session.audioMix = mix; audioMix = mix
        }
        if !ringtone && ["wav", "aiff", "caf"].contains(format) { return try await exportPCM(composition, mix: audioMix, format: format, name: url.deletingPathExtension().lastPathComponent) }
        let target = try FileStore.destination(L("{0}-剪辑.m4a", String(describing: url.deletingPathExtension().lastPathComponent)))
        do { try await withTaskCancellationHandler { try await session.export(to: target, as: .m4a) } onCancel: { session.cancelExport() }; try Task.checkCancellation() }
        catch { try? FileManager.default.removeItem(at: target); throw error }
        if ringtone { let renamed = target.deletingPathExtension().appendingPathExtension("m4r"); try FileManager.default.moveItem(at: target, to: renamed); return renamed }
        return target
    }
    private func exportPCM(_ composition: AVMutableComposition, mix: AVAudioMix?, format: String, name: String) async throws -> URL {
        let url = try FileStore.destination(name + L("-剪辑.") + format)
        let reader = try AVAssetReader(asset: composition)
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
        output.audioMix = mix
        guard reader.canAdd(output) else { throw ToolFailure(message: L("无法解码此音频。")) }; reader.add(output)
        let type: AVFileType = format == "wav" ? .wav : format == "aiff" ? .aiff : .caf
        let writer = try AVAssetWriter(outputURL: url, fileType: type)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: format == "aiff", AVLinearPCMIsNonInterleaved: false])
        guard writer.canAdd(input) else { throw ToolFailure(message: L("当前设备不支持该输出格式。")) }; writer.add(input)
        do {
            guard writer.startWriting() else { throw writer.error ?? ToolFailure(message: L("无法开始音频写入。")) }
            writer.startSession(atSourceTime: .zero)
            guard reader.startReading() else { throw reader.error ?? ToolFailure(message: L("无法读取音轨。")) }
            while let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    if writer.status == .failed { throw writer.error ?? ToolFailure(message: L("音频写入失败。")) }
                    try await Task.sleep(for: .milliseconds(10))
                }
                guard input.append(sample) else { throw writer.error ?? ToolFailure(message: L("音频写入失败。")) }
            }
            guard reader.status == .completed else { throw reader.error ?? ToolFailure(message: L("音频解码未完成。")) }
            input.markAsFinished(); await writer.finishWriting(); try Task.checkCancellation()
            guard writer.status == .completed else { throw writer.error ?? ToolFailure(message: L("音频导出失败。")) }
            return url
        } catch { reader.cancelReading(); writer.cancelWriting(); try? FileManager.default.removeItem(at: url); throw error }
    }
    func prepare(_ url: URL) async throws -> URL {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true {
            let info = try await inspect(url)
            return try await export(url, start: 0, end: info.duration, fade: 0, ringtone: false)
        }
        return url
    }
    func waveform(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { return [] }
        var peaks = [Float](repeating: 0, count: 120)
        var offset: Int64 = 0
        while file.framePosition < file.length {
            try Task.checkCancellation(); try file.read(into: buffer)
            guard buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] else { break }
            for index in 0..<Int(buffer.frameLength) {
                let bin = min(119, Int((offset + Int64(index)) * 120 / max(file.length, 1)))
                peaks[bin] = max(peaks[bin], abs(samples[index]))
            }
            offset += Int64(buffer.frameLength)
        }
        let maximum = max(peaks.max() ?? 1, 0.001)
        return peaks.map { $0 / maximum }
    }

}
