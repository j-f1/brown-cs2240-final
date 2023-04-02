//
//  MetalViewRepresentable.swift
//  Phone-ton
//
//  Created by Jed Fox on 2023-04-02.
//

import MetalKit
import SwiftUI

struct MetalView {
    class Coordinator {
        var renderer: Renderer?
    }
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeView(context: Context) -> MTKView {
        let view = MTKView()
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        view.device = defaultDevice

        context.coordinator.renderer = Renderer(metalKitView: view)
        view.delegate = context.coordinator.renderer

        return view
    }
}

#if os(macOS)
extension MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        makeView(context: context)
    }
    func updateNSView(_ nsView: MTKView, context: Context) {}
}
#elseif os(iOS)
extension MetalView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        makeView(context: context)
    }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}
#else
#error("Unsupported OS!")
#endif
