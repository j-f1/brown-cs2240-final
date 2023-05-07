import SwiftUI
import UniformTypeIdentifiers

// TODO: fix text field display on iOS
struct GUIView: View {
    @Binding var model: URL?
    @Binding var nextSettings: RenderSettings

    @State private var selectingModel = false

    init(nextSettings: Binding<RenderSettings>, model: Binding<URL?>) {
        self._model = model
        self._nextSettings = nextSettings
    }

    private func sectionHeader(_ label: LocalizedStringKey) -> Text {
        #if os(macOS)
        Text(label).font(.headline)
        #else
        Text(label)
        #endif
    }

    struct ModelLabel: View {
        let model: URL?

        var body: some View {
            if let model {
                HStack(spacing: 0) {
                    Image(systemName: "cube.transparent").imageScale(.small)
                    Text(" \(model.lastPathComponent)")
                }
            } else {
                Text("Select Model")
            }
        }
    }

    struct ModelPicker: View {
        @Binding var model: URL?

        private func contents(of directory: URL = Bundle.main.url(forResource: "models", withExtension: nil)!) -> [URL] {
            try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "obj" || $0.hasDirectoryPath }
        }

        var body: some View {
            Section {
                Picker("", selection: $model) {
                    ForEach(contents().filter { !$0.hasDirectoryPath }, id: \.self) { file in
                        Text(file.lastPathComponent.replacingOccurrences(of: ".obj", with: "")).tag(file as URL?)
                    }
                }.labelsHidden()
            }
            ForEach(contents().filter(\.hasDirectoryPath), id: \.self) { dir in
                let picker = Picker(dir.lastPathComponent, selection: $model) {
                    ForEach(contents(of: dir), id: \.self) { file in
                        Text(
                            file.lastPathComponent
                                .replacingOccurrences(of: dir.lastPathComponent + "-", with: "")
                                .replacingOccurrences(of: ".obj", with: "")
                        ).tag(file as URL?)
                    }
                }
                #if os(iOS)
                Section(header: Text(dir.lastPathComponent).textCase(nil)) {
                    picker.labelsHidden()
                }
                #else
                picker
                #endif
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Form {
                #if os(iOS)
                Section("Model") {
                    NavigationLink {
                        Form {
                            Button {
                                selectingModel = true
                            } label: {
                                Label("Import from Files…", systemImage: "folder")
                            }
                            ModelPicker(model: $model)
                        }.pickerStyle(.inline)
                    } label: {
                        ModelLabel(model: model)
                    }
                }
                #else
                Section {
                    Menu {
                        ModelPicker(model: $model)
                    } label: {
                        ModelLabel(model: model)
                    } primaryAction: {
                        selectingModel = true
                    }.pickerStyle(.inline)
                }
                Divider()
                #endif
                Section(header: sectionHeader("BSSDFs").textCase(nil)) {
                    Toggle("Diffuse", isOn: $nextSettings.diffuseOn)
                    Toggle("Mirror", isOn: $nextSettings.mirrorOn)
                    // Toggle("Refract", isOn: $nextSettings.refractionOn)
                    // Toggle("Glossy", isOn: $nextSettings.glossyOn)
                    Toggle("Subsurface Scattering", isOn: $nextSettings.subsurfaceScatteringOn)
                    Toggle("Single Scattering", isOn: $nextSettings.singleSSOn)
                        .padding(.leading)
                    Toggle("Simulated Diffusion", isOn: $nextSettings.diffusionSSOn)
                        .padding(.leading)
                    Toggle("Importance Sampling", isOn: $nextSettings.importanceSamplingOn)
                }
                #if os(macOS)
                Divider()
                #endif
                Section(header: sectionHeader("Ray-Tracing Behavior Settings")) {
                    TextField( value: $nextSettings.samplesPerPixel,
                               format: .number, prompt: Text("Samples Per Pixel")) {
                        Text("Samples Per Pixel")
                    }
                    Toggle("Direct Lighting", isOn: $nextSettings.directLightingOn)
                    TextField( value: $nextSettings.directLightingSamples,
                               format: .number, prompt: Text("Samples Per Light")) {
                        Text("Samples Per Light")
                    }
                    // Toggle("Glass Transmittance", isOn: $nextSettings.glassTransmittanceOn)
                    TextField(
                        value: $nextSettings.russianRoulette,
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

                Section(header: sectionHeader("Image Settings")) {

                    TextField(value: $nextSettings.toneMap[0], format: .number, prompt: Text("Tone Mapping R")) {
                        Text("Tone Mapping R")
                    }
                    TextField(value: $nextSettings.toneMap[1], format: .number, prompt: Text("Tone Mapping G")) {
                        Text("Tone Mapping G")
                    }
                    TextField(value: $nextSettings.toneMap[2], format: .number, prompt: Text("Tone Mapping B")) {
                        Text("Tone Mapping B")
                    }
                    TextField(value: $nextSettings.gammaCorrection, format: .number, prompt: Text("Gamma Correction")) {
                        Text("Gamma Correction")
                    }
                    TextField(value: $nextSettings.imageWidth, format: .number, prompt: Text("Image width")) {
                        Text("Image width")
                    }
                    TextField(value: $nextSettings.imageHeight, format: .number, prompt: Text("Image height")) {
                        Text("Image height")
                    }

                }
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif
            }
        }
        .fileImporter(isPresented: $selectingModel, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                model = url
            }
        }
        #if os(macOS)
        .fixedSize(horizontal: true, vertical: false)
        #endif
    }
}

struct GUIView_Previews: PreviewProvider {
    static var previews: some View {
        GUIView(nextSettings: .constant(RenderSettings()), model: .constant(nil))
    }
}
