import SwiftUI

struct GUIView: View {
    @Binding var settings: RenderSettings
    @Binding var filepath: String;
    //TODO INITIALIZE THIS BETTER
    @State private var stateSettings: RenderSettings = RenderSettings(diffuseOn: true, mirrorOn: true, refractionOn: true, glossyOn: true,subsurfaceScatteringOn: true, ssSigma_s: 1.0,ssSigma_a: simd_float3(0.01, 0.1, 1.0), ssEta: 1, ssG: 0, directLightingOn: true, importanceSamplingOn: true, glassTransmittanceOn: true, russianRoulette: 0.9,samplesPerPixel: 16, toneMap: simd_float3(0.299, 0.587, 0.114), gammaCorrection: 0.4,imageWidth: 512, imageHeight: 512
    );
    @State private var samplesPerPixel = 0;
    
    func submitSettings() {
        settings = stateSettings;
    }
    
    func selectFile() {
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a file| Our Code World";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        //TODO FILTER BY OBJ TYPE (USE UTType??)
        //        dialog.allowedContentTypes        = ["obj"];
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            if (result != nil) {filepath = result!.path;}
        } else {
            // User clicked on "Cancel"
            return
        }
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
                    Button (action: selectFile) {
                        Text("Select File")
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
                    Button(action: submitSettings) {
                        Text("Rerender");
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
        GUIView(settings: .constant(RenderSettings()), filepath: .constant("cow.obj"))
    }
}
