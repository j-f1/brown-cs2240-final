import SwiftUI

struct ContentView: View {
    // TODO: THIS IS A BAD PLACE FOR THESE INITIAL VALUES SO FIGURE SOMETHING OUT (PROBABLY DEFINE A MACRO)
    @State var settings: RenderSettings = .init(diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true, subsurfaceScatteringOn: true, ssSigma_s: 1.0, ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, directLightingSamples: 5, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9, samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4, imageWidth: 512, imageHeight: 512)
    @State var model = Bundle.main.url(forResource: "CornellBox-Original", withExtension: "obj", subdirectory: "models/CornellBox")

    @Environment(\.displayScale) private var scale

    var body: some View {
        HStack {
            GUIView(settings: $settings, model: $model)
            if let model {
                MetalView(settings: settings, model: model)
                    .frame(width: CGFloat(settings.imageWidth) / scale, height: CGFloat(settings.imageHeight) / scale)
                    .id(model) // tear down and rebuild view when changing model for now
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
