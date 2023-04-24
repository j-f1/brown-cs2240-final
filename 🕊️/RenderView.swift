import SwiftUI

struct RenderView: View {
    let settings: RenderSettings
    let model: URL?
    @Binding var renderer: Renderer?

    @Environment(\.displayScale) private var scale

    private struct RenderResult: View {
        @ObservedObject var renderer: Renderer

        var body: some View {
            VStack {
                if let content = renderer.content, let ciImage = CIImage(mtlTexture: content, options: [.colorSpace: CGColorSpace.sRGB]) {
                    #if canImport(AppKit)
                    let image = Image(nsImage: content.image)
                    #else
                    let image = Image(uiImage: content.image)
                    #endif
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.secondary
                }
            }.opacity(renderer.rendering ? 0.5 : 1)
        }
    }

    var body: some View {
        Group {
            if let renderer {
                RenderResult(renderer: renderer)
            } else {
                Color.secondary.overlay(ProgressView())
            }
        }
        .frame(width: settings.size.width / scale, height: settings.size.height / scale)

    }
}

private extension MTLTexture {
    #if canImport(AppKit)
    typealias ImageType = NSImage
    #else
    typealias ImageType = UIImage
    #endif
    var image: ImageType {
        let pixelBytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocatedSize, alignment: MemoryLayout<UInt8>.alignment)
        let bytesPerRow = allocatedSize / height
        self.getBytes(pixelBytes.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegion(origin: .zero, size: MTLSize(width: width, height: height, depth: depth)), mipmapLevel: 0)
        let provider = CGDataProvider(dataInfo: nil, data: pixelBytes.baseAddress!, size: pixelBytes.count, releaseData: { _, data, _ in data.deallocate() })
        let cgImage = CGImage(
            width: width, height: height,
            bitsPerComponent: MemoryLayout<UInt8>.size * 8,
            bitsPerPixel: MemoryLayout<UInt8>.size * 8 * 4,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: [.init(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)],
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .absoluteColorimetric
        )!
        #if canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}

struct RenderView_Previews: PreviewProvider {
    static var previews: some View {
        RenderView(settings: .init(), model: nil, renderer: .constant(nil))
    }
}
