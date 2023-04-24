import SwiftUI
import UniformTypeIdentifiers

// TODO: fix text field display on iOS
struct GUIView: View {
    @Binding var settings: RenderSettings
    @Binding var model: URL?

    @State private var stateSettings: RenderSettings
    @State private var selectingModel = false

    init(settings: Binding<RenderSettings>, model: Binding<URL?>) {
        self._settings = settings
        self._model = model
        self._stateSettings = .init(initialValue: settings.wrappedValue)
    }

    private func sectionHeader(_ label: LocalizedStringKey) -> Text {
        #if os(macOS)
        Text(label).font(.headline)
        #else
        Text(label)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Form {
                #if os(iOS)
                let header = Text("Model")
                #else
                let header = EmptyView()
                #endif
                Section(header: header) {
                    Button(action: { selectingModel = true }) {
                        if let model {
                            HStack(spacing: 0) {
                                Image(systemName: "cube.transparent")
                                Text(" \(model.lastPathComponent)")
                            }
                        } else {
                            Text("Select File")
                        }
                    }.fileImporter(isPresented: $selectingModel, allowedContentTypes: [.data]) { result in
                        if case .success(let url) = result {
                            model = url
                        }
                    }
                }
                #if os(macOS)
                Divider()
                #endif
                Section(header: sectionHeader("BSSDFs").textCase(nil)) {
                    Toggle("Diffuse", isOn: $stateSettings.diffuseOn)
                    Toggle("Mirror", isOn: $stateSettings.mirrorOn)
                    Toggle("Refract", isOn: $stateSettings.refractionOn)
                    Toggle("Glossy", isOn: $stateSettings.glossyOn)
                    Toggle("Subsurface Scattering", isOn: $stateSettings.subsurfaceScatteringOn)
                    Toggle("Importance Sampling", isOn: $stateSettings.importanceSamplingOn)
                }
                #if os(macOS)
                Divider()
                #endif
                Section(header: sectionHeader("Ray-Tracing Behavior Settings")) {
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
                    }
                }
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif

                #if os(macOS)
                Divider()
                #endif
                Section(header: sectionHeader("Image Settings"), footer: Text("Click re-render to implement all settings")) {
                    
                    TextField(value: $stateSettings.toneMap[0], format: .number, prompt: Text("Tone Mapping R")) {
                        Text("Tone Mapping R")
                    }
                    TextField(value: $stateSettings.toneMap[1], format: .number, prompt: Text("Tone Mapping G")) {
                        Text("Tone Mapping G")
                    }
                    TextField(value: $stateSettings.toneMap[2], format: .number, prompt: Text("Tone Mapping B")) {
                        Text("Tone Mapping B")
                    }
                    TextField(value: $stateSettings.gammaCorrection, format: .number, prompt: Text("Gamma Correction")) {
                        Text("Gamma Correction")
                    }
                    TextField(value: $stateSettings.imageWidth, format: .number, prompt: Text("Image width")) {
                        Text("Image width")
                    }
                    TextField(value: $stateSettings.imageHeight, format: .number, prompt: Text("Image height")) {
                        Text("Image height")
                    }
                    
                }
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif

                #if os(macOS)
                Divider()
                #endif
                Section {
                    Button("Rerender") {
                        stateSettings.frameIndex += 1
                        settings = stateSettings
                    }
                }
            }
        }
        #if os(macOS)
        .fixedSize(horizontal: true, vertical: false)
        #endif
    }
}

struct GUIView_Previews: PreviewProvider {
    static var previews: some View {
        GUIView(settings: .constant(RenderSettings()), model: .constant(nil))
    }
}
