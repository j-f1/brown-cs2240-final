import SwiftUI

struct ContentView: View {
    // TODO: THIS IS A BAD PLACE FOR THESE INITIAL VALUES SO FIGURE SOMETHING OUT (PROBABLY DEFINE A MACRO)
    @State var settings: RenderSettings = .init(diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true, subsurfaceScatteringOn: true, ssSigma_s: 1.0, ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9, samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4, imageWidth: 512, imageHeight: 512)
    @State var filepath: String = "cow.obj"
//    @State var settings: RenderSettings = DEFAULT_SETTINGS;

    @Environment(\.displayScale) private var scale

    var body: some View {
        HStack {
            GUIView(settings: $settings, filepath: $filepath)
            MetalView(settings: settings, model: Bundle.main.url(forResource: "CornellBox-Original", withExtension: "obj", subdirectory: "models/CornellBox"))
                .frame(width: CGFloat(settings.imageWidth) / scale, height: CGFloat(settings.imageHeight) / scale)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
