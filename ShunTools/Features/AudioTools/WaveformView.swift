import SwiftUI

struct WaveformView: View {
    let peaks: [Float]
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    @State private var dragStart: Double?
    @State private var dragEnd: Double?
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let left = width * start / max(duration, 0.01)
            let right = width * end / max(duration, 0.01)
            ZStack(alignment: .leading) {
                Canvas { context, size in
                    for (index, peak) in peaks.enumerated() {
                        let x = CGFloat(index) / CGFloat(max(peaks.count - 1, 1)) * size.width
                        let height = max(3, CGFloat(peak) * (size.height - 32))
                        let selected = x >= left && x <= right
                        let rect = CGRect(x: x, y: (size.height - height) / 2, width: 2.5, height: height)
                        context.fill(Path(roundedRect: rect, cornerRadius: 1.25), with: .color(selected ? .purple : .secondary.opacity(0.25)))
                    }
                }
                RoundedRectangle(cornerRadius: 8).stroke(.purple, lineWidth: 2).background(.purple.opacity(0.05)).frame(width: max(1, right - left)).offset(x: left)
                handle.offset(x: left - 15).gesture(DragGesture(minimumDistance: 0).onChanged { value in if dragStart == nil { dragStart = start }; start = max(0, min(end - 0.1, (dragStart ?? start) + value.translation.width / width * duration)) }.onEnded { _ in dragStart = nil; dragEnd = nil })
                handle.offset(x: right - 15).gesture(DragGesture(minimumDistance: 0).onChanged { value in if dragEnd == nil { dragEnd = end }; end = max(start + 0.1, min(duration, (dragEnd ?? end) + value.translation.width / width * duration)) }.onEnded { _ in dragStart = nil; dragEnd = nil })
            }
        }.frame(height: 108).accessibilityElement(children: .ignore).accessibilityLabel(L("真实音频波形，可使用下方时间滑块调整片段"))
    }
    private var handle: some View { RoundedRectangle(cornerRadius: 6).fill(.purple).frame(width: 6, height: 64).frame(width: 30, height: 108).contentShape(Rectangle()) }
}
