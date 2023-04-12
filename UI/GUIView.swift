import SwiftUI

struct GUIView: View {
    //TODO MOVE THESE AND MAKE THEM NOT DUMB
    @State private var diffuseOn: Bool = true
    @State private var mirrorOn: Bool = true
    @State private var refractOn: Bool = true
    @State private var glossyOn: Bool = true
    @State private var subScOn: Bool = true
    @State private var impSamplingOn: Bool = true
    @State private var directLOn: Bool = true
    @State private var glassTransOn: Bool = true
    @State private var sppString: String = ""
//    @FocusState private var sppFieldIsFocused: Bool = false
    
    var body: some View {
        VStack (alignment: .leading) {
            VStack{
                Button (action: selectFile) {
                    Text("Select File")
                }
            }
            VStack {
                Text("BSSDFs")
                Toggle("Diffuse", isOn: $diffuseOn)
                Toggle("Mirror", isOn: $mirrorOn)
                Toggle("Refract", isOn: $refractOn)
                Toggle("Glossy", isOn: $glossyOn)
                Toggle("Subsurface Scattering", isOn: $subScOn)
                Toggle("Importance Sampling", isOn: $impSamplingOn)
            }
            VStack {
                TextField(
                        "Samples Per Pixel",
                        text: $sppString
                    )
//                    .focused($sppFieldIsFocused)
                    .onSubmit {
                        selectFile()
                    }
                    .disableAutocorrection(true)
                    .border(.secondary)
                Toggle("Direct Lighting", isOn: $directLOn)
                Toggle("Glass Transmittance", isOn: $glassTransOn)
                Text("Russian Roulette")
                Text("Tone Mapping")
                Text("Gamma Correction")
                Text("Image width")
                Text("Image height")
            }
        }
        .padding(20)
    }
}

struct GUIView_Previews: PreviewProvider {
    static var previews: some View {
        GUIView()
    }
}

//TODO MOVE THESE AND MAKE THEM NOT DUMB
func selectFile() {
    print("File Selected")
}
