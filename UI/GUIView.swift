import SwiftUI

struct GUIView: View {
    @Binding var settings: RenderSettings
    //TODO MOVE THESE AND MAKE THEM NOT DUMB
    @State private var stateSettings: RenderSettings = RenderSettings();
    @State private var samplesPerPixel = 0;
    
    var body: some View {
        VStack (alignment: .leading) {
            VStack{
                Button (action: selectFile) {
                    Text("Select File")
                }
            }
            VStack {
                Text("BSSDFs")
                Toggle("Diffuse", isOn: $stateSettings.diffuseOn)
                Toggle("Mirror", isOn: $stateSettings.mirrorOn)
                Toggle("Refract", isOn: $stateSettings.refractionOn)
                Toggle("Glossy", isOn: $stateSettings.glossyOn)
                Toggle("Subsurface Scattering", isOn: $stateSettings.subsurfaceScatteringOn)
                Toggle("Importance Sampling", isOn: $stateSettings.importanceSamplingOn)
            }
            VStack {
                TextField(
                        "Samples Per Pixel",
                        value: $stateSettings.samplesPerPixel,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .border(.secondary)
                Toggle("Direct Lighting", isOn: $stateSettings.directLightingOn)
                Toggle("Glass Transmittance", isOn: $stateSettings.glassTransmittanceOn)
                Form {
                    TextField("Russian Roulette", value: $stateSettings.russianRoulette, format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Tone Mapping R", value: $stateSettings.toneMap[0], format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Tone Mapping G", value: $stateSettings.toneMap[1], format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Tone Mapping B", value: $stateSettings.toneMap[2], format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Gamma Correction", value: $stateSettings.gammaCorrection, format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Image width", value: $stateSettings.imageWidth, format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                    TextField("Image height", value: $stateSettings.imageHeight, format: .number).textFieldStyle(.roundedBorder) {
                        Text("Russian Roulette")
                    }
                }
            }
        }
        .padding(20)
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

