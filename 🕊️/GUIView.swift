import SwiftUI
import UniformTypeIdentifiers

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
    
    func exportImage() -> URL?{
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save your image"
        savePanel.message = "Choose a folder and a name to store the image."
        savePanel.nameFieldLabel = "Image file name:"
        
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }
    
    func savePNG(imageName: String, path: URL) {
        let image = NSImage(named: imageName)!
        let imageRepresentation = NSBitmapImageRep(data: image.tiffRepresentation!)
        let pngData = imageRepresentation?.representation(using: .png, properties: [:])
        do {
            try pngData!.write(to: path)
        } catch {
            print(error)
        }
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Form {
                Section {
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
                Divider()
                Section (header: Text("BSSDFs").bold()){
                    Toggle("Diffuse", isOn: $stateSettings.diffuseOn)
                    Toggle("Mirror", isOn: $stateSettings.mirrorOn)
                    Toggle("Refract", isOn: $stateSettings.refractionOn)
                    Toggle("Glossy", isOn: $stateSettings.glossyOn)
                    Toggle("Subsurface Scattering", isOn: $stateSettings.subsurfaceScatteringOn)
                    Toggle("Importance Sampling", isOn: $stateSettings.importanceSamplingOn)
                }
                Divider()
                Section (header: Text("Ray-Tracing Behavior Settings").bold()) {
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
                Section (header: Text("Image Settings").bold(), footer: Text("Click re-render to implement all settings")) {
                    
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
                    Button("Rerender") {
                        stateSettings.frameIndex += 1
                        settings = stateSettings
                    }
                }
                Section {
                    Button("Export Image") {
                        if let url = exportImage() {
//                            savePNG(imageName: "cow", path: url)
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct GUIView_Previews: PreviewProvider {
    static var previews: some View {
        GUIView(settings: .constant(RenderSettings()), model: .constant(nil))
    }
}
