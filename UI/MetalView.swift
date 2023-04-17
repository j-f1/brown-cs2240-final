import MetalKit
import SwiftUI

struct MetalView {
    let settings: RenderSettings
    let model: URL?

    class Coordinator {
        var renderer: Renderer?
        let model: URL?

        init(model: URL?) {
            self.model = model
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeView(context: Context) -> MTKView {
        let view = MTKView(frame: .init(origin: .zero, size: .init(width: 512, height: 512)))
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        view.device = defaultDevice
        view.framebufferOnly = false

        Task.detached {
            let renderer = await Renderer(metalKitView: view, modelURL: model, settings: settings)
            if renderer == nil { assertionFailure() }
            await MainActor.run {
                context.coordinator.renderer = renderer
                view.delegate = renderer
            }
        }

        return view
    }

    func updateView(_ view: MTKView, context: Context) {
        assert(model == context.coordinator.model)
        context.coordinator.renderer?.settings = settings
    }
}

#if os(macOS)
extension MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        makeView(context: context)
    }
    func updateNSView(_ nsView: MTKView, context: Context) {
        updateView(nsView, context: context)
    }
}
#elseif os(iOS)
extension MetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        makeView(context: context)
    }
    func updateUIView(_ uiView: MTKView, context: Context) {
        updateView(uiView, context: context)
    }
}
#else
#error("Unsupported OS!")
#endif
