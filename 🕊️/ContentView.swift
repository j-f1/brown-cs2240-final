import SwiftUI

struct ContentView: View {
    @State var settings = RenderSettings.default
    @State var model = Bundle.main.url(forResource: "CornellBox-Original", withExtension: "obj", subdirectory: "models/CornellBox")

    var body: some View {
        HStack {
            GUIView(settings: $settings, model: $model)
            RenderView(settings: settings, model: model)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
