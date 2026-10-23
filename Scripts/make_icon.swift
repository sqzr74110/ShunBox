import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// Composite the original pixels over a solid mint background, without generative edits.
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot read source image") }
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.81, green: 0.91, blue: 0.82, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
let scale = min(900 / Double(image.width), 900 / Double(image.height))
let width = Double(image.width)*scale, height = Double(image.height)*scale
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: (1024-width)/2, y: (1024-height)/2, width: width, height: height))
let output = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
guard CGImageDestinationFinalize(output) else { fatalError("Cannot write icon") }
