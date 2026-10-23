#if DEBUG && targetEnvironment(simulator)
import UIKit
/// Simulator-only fixtures for first-presentation regression testing.
enum PreviewFixtures {
    @MainActor static func prepare() async {
        do {
            let url = try FileStore.destination("Preview-Test.png")
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 700), format: format).image { ctx in
                let cg = ctx.cgContext
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.systemIndigo.cgColor, UIColor.systemPink.cgColor, UIColor.systemOrange.cgColor] as CFArray, locations: [0, 0.6, 1])!
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1000, y: 700), options: [])
                UIColor.white.withAlphaComponent(0.7).setFill(); UIBezierPath(ovalIn: CGRect(x: 650, y: 100, width: 120, height: 120)).fill()
                UIColor(white: 0.12, alpha: 0.8).setFill()
                let mountain = UIBezierPath(); mountain.move(to: CGPoint(x: 0, y: 700)); mountain.addLine(to: CGPoint(x: 420, y: 280)); mountain.addLine(to: CGPoint(x: 1000, y: 700)); mountain.close(); mountain.fill()
            }
            try image.pngData()!.write(to: url)
            let options = ImageOptions(format: "png", watermark: "SHUNBOX / STUDIO", watermarkStyle: .glassFooter)
            let output = try await ImageProcessor.shared.process([url], options: options)
            _ = try await MediaArchive.shared.save(output[0])
            let pdf = try await ImageProcessor.shared.process([url], options: ImageOptions(format: "pdf"))
            _ = try await MediaArchive.shared.save(pdf[0])
        } catch { print("Preview fixture: \(error)") }
    }
}
#endif
