import SwiftUI
import UniformTypeIdentifiers

// TODO: fix text field display on iOS
struct GUIView: View {
    @Binding var model: URL?
    @Binding var nextSettings: RenderSettings

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

    struct ModelPicker: View {
        @Binding var model: URL?

        @State private var selectingModel = false

        private func contents(of directory: URL = Bundle.main.url(forResource: "models", withExtension: nil)!) -> [URL] {
            try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "obj" || $0.hasDirectoryPath }
        }

        var body: some View {
            Menu {
                Picker("", selection: $model) {
                    ForEach(contents().filter { !$0.hasDirectoryPath }, id: \.self) { file in
                        Text(file.lastPathComponent.replacingOccurrences(of: ".obj", with: "")).tag(file as URL?)
                    }
                }.labelsHidden()
                ForEach(contents().filter(\.hasDirectoryPath), id: \.self) { dir in
                    Picker(dir.lastPathComponent, selection: $model) {
                        ForEach(contents(of: dir), id: \.self) { file in
                            Text(
                                file.lastPathComponent
                                    .replacingOccurrences(of: dir.lastPathComponent + "-", with: "")
                                    .replacingOccurrences(of: ".obj", with: "")
                            ).tag(file as URL?)
                        }
                    }
                }
            } label: {
                if let model {
                    HStack(spacing: 0) {
                        Image(systemName: "cube.transparent").imageScale(.small)
                        Text(" \(model.lastPathComponent)")
                    }
                } else {
                    Text("Select File")
                }
            } primaryAction: {
                selectingModel = true
            }.fileImporter(isPresented: $selectingModel, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result {
                    model = url
                }
            }.pickerStyle(.inline)
        }
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
                    ModelPicker(model: $model)
                }
                #if os(macOS)
                Divider()
                #endif
                Section(header: sectionHeader("BSSDFs").textCase(nil)) {
                    Toggle("Diffuse", isOn: $nextSettings.diffuseOn)
                    Toggle("Mirror", isOn: $nextSettings.mirrorOn)
                    Toggle("Refract", isOn: $nextSettings.refractionOn)
                    Toggle("Glossy", isOn: $nextSettings.glossyOn)
                    Toggle("Subsurface Scattering", isOn: $nextSettings.subsurfaceScatteringOn)
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
                    Toggle("Glass Transmittance", isOn: $nextSettings.glassTransmittanceOn)
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
