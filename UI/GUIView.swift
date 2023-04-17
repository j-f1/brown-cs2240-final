import SwiftUI

struct GUIView: View {
    @Binding var settings: RenderSettings
    
    //TODO INITIALIZE THIS BETTER
    @State private var stateSettings: RenderSettings = RenderSettings(diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true,subsurfaceScatteringOn: true, ssSigma_s: 1.0,ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9,samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4,imageWidth: 512, imageHeight: 512
    );
    @State private var samplesPerPixel = 0;
    
    func submitSettings() {
        settings = stateSettings;
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Form {
                Section {
                    Button (action: selectFile) {
                        Text("Select File")
                    }
                }
                Divider()
                Section (header: Text("BSSDFs")){
                    Toggle("Diffuse", isOn: $stateSettings.diffuseOn)
                    Toggle("Mirror", isOn: $stateSettings.mirrorOn)
                    Toggle("Refract", isOn: $stateSettings.refractionOn)
                    Toggle("Glossy", isOn: $stateSettings.glossyOn)
                    Toggle("Subsurface Scattering", isOn: $stateSettings.subsurfaceScatteringOn)
                    Toggle("Importance Sampling", isOn: $stateSettings.importanceSamplingOn)
                }
                Divider()
                Section (header: Text("Ray-Tracing Behavior Settings")) {
                    TextField( value: $stateSettings.samplesPerPixel,
                               format: .number, prompt: Text("Samples Per Pixel")) {
                        Text("Samples Per Pixel")
                    }
                    Toggle("Direct Lighting", isOn: $stateSettings.directLightingOn)
                    Toggle("Glass Transmittance", isOn: $stateSettings.glassTransmittanceOn)
                    TextField(
                        value: $stateSettings.russianRoulette,
                        format: .number, prompt: Text("Russian Roulette"))
                    {
                        Text("Russian Roulette")
                    }.textFieldStyle(.roundedBorder)
                }
                Divider()
                Section (header: Text("Image Settings"), footer: Text("Click re-render to implement all settings")) {
                    
                    TextField(value: $stateSettings.toneMap[0], format: .number, prompt: Text("Tone Mapping R")) {
                        Text("Tone Mapping R")
                    }.textFieldStyle(.roundedBorder)
                    TextField(value: $stateSettings.toneMap[1], format: .number, prompt: Text("Tone Mapping G")) {
                        Text("Tone Mapping G")
                    }.textFieldStyle(.roundedBorder)
                    TextField(value: $stateSettings.toneMap[2], format: .number, prompt: Text("Tone Mapping B")) {
                        Text("Tone Mapping B")
                    }.textFieldStyle(.roundedBorder)
                    TextField(value: $stateSettings.gammaCorrection, format: .number, prompt: Text("Gamma Correction")) {
                        Text("Gamma Correction")
                    }.textFieldStyle(.roundedBorder)
                    TextField(value: $stateSettings.imageWidth, format: .number, prompt: Text("Image width")) {
                        Text("Image width")
                    }.textFieldStyle(.roundedBorder)
                    TextField(value: $stateSettings.imageHeight, format: .number, prompt: Text("Image height")) {
                        Text("Image height")
                    }.textFieldStyle(.roundedBorder)
                    
                }
                Divider()
                Section {
                    Button(action: submitSettings) {
                        Text("Rerender");
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct GUIView_Previews: PreviewProvider {
    static var previews: some View {
        GUIView(settings: .constant(RenderSettings()))
    }
}

//TODO MOVE THESE AND MAKE THEM NOT DUMB
func selectFile() {
    print("File Selected")
}
