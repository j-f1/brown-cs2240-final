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
                    let image = Image(nsImage: {
                        let imageRep = NSCIImageRep(ciImage: ciImage)
                        let image = NSImage(size: imageRep.size)
                        image.addRepresentation(imageRep)
                        return image
                    }())
                    #else
                    let image = Image(uiImage: UIImage(ciImage: ciImage))
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

struct RenderView_Previews: PreviewProvider {
    static var previews: some View {
        RenderView(settings: .init(), model: nil, renderer: .constant(nil))
    }
}
