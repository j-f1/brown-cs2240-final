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
                .sorted(using: KeyPathComparator(\.lastPathComponent.localizedLowercase))
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

    struct FakeLabel<Label: View, Content: View>: View {
        let label: Label
        let content: Content

        init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text {
            self.label = Text(label)
            self.content = content()
        }
        init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
            self.label = label()
            self.content = content()
        }

        var body: some View {
            LabeledContent {
                HStack(spacing: 0) {
                    label.frame(width: 100, alignment: .trailing)
                    content.textFieldStyle(.squareBorder)
                }.padding(.leading, -48)
            } label: {}
        }
    }

    func variable(_ name: LocalizedStringKey, `subscript` s: LocalizedStringKey) -> some View {
        (Text(name) + Text(s).baselineOffset(-5).font(.footnote).italic())
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
                     Toggle("Glossy", isOn: $nextSettings.glossyOn)
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

                Section(header: sectionHeader("Subsurface Material Settings")) {
                    Menu("Presets") {
                        ForEach(Array(SubsurfaceMaterial.all).sorted(using: KeyPathComparator(\.key)), id: \.key) { name, material in
                            Button(name) {
                                nextSettings.ss = material
                            }
                        }
                    }
                    FakeLabel {
                        HStack(spacing: 0) {
                            TextField("", value: $nextSettings.ss.sigma_s_prime.x, format: .number)
                            TextField("", value: $nextSettings.ss.sigma_s_prime.y, format: .number)
                            TextField("", value: $nextSettings.ss.sigma_s_prime.z, format: .number)
                        }.frame(width: 180)
                    } label: {
                        variable("σ", subscript: "s")
                    }
                    FakeLabel {
                        HStack(spacing: 0) {
                            TextField("", value: $nextSettings.ss.sigma_a.x, format: .number)
                            TextField("", value: $nextSettings.ss.sigma_a.y, format: .number)
                            TextField("", value: $nextSettings.ss.sigma_a.z, format: .number)
                        }.frame(width: 180)
                    } label: {
                        variable("σ", subscript: "a")
                    }
                    TextField(value: $nextSettings.ss.eta, format: .number, prompt: Text("Index of Refraction")) {
                        Text("Index of Refraction")
                    }
                    TextField(value: $nextSettings.ss.g, format: .number, prompt: Text("g").italic()) {
                        Text("g").italic()
                    }
                }
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif

                #if os(macOS)
                Divider()
                #endif

                Section(header: sectionHeader("Image Settings")) {
                    FakeLabel("Tone Mapping") {
                        HStack(spacing: 0) {
                            TextField("", value: $nextSettings.toneMap.x, format: .number)
                            TextField("", value: $nextSettings.toneMap.y, format: .number)
                            TextField("", value: $nextSettings.toneMap.z, format: .number)
                        }.frame(width: 180)
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
