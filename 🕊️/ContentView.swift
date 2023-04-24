import SwiftUI

struct ContentView: View {
    @State var settings = RenderSettings.default
    @State var model = Bundle.main.url(forResource: "CornellBox-Original", withExtension: "obj", subdirectory: "models/CornellBox")

    // needs to be kept here since iOS destroys tabs when navigating away from them
    @State private var renderer: Renderer?

    @State private var selectedTab = 0

    var content: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            NavigationStack {
                GUIView(settings: $settings, model: $model)
                    .navigationTitle("Render Settings")
            }
            .tag(0)
            .tabItem { Label("Setup", systemImage: "gearshape.fill") }

            RenderView(settings: settings, model: model, renderer: $renderer)
                .tag(1)
                .tabItem { Label("Render", systemImage: "photo.fill") }
        }
        #else
        HStack {
            GUIView(settings: $settings, model: $model)
            RenderView(settings: settings, model: model)
        }
        .padding()
        #endif
    }

    var body: some View {
        content
            .task(id: model) {
                guard let model else {
                    renderer = nil
                    return
                }
                renderer = await Renderer(
                    device: MTLCreateSystemDefaultDevice()!,
                    modelURL: model,
                    settings: settings
                )
                renderer?.render()
            }
            .onChange(of: settings) { newValue in
                renderer?.settings = settings
                renderer?.render()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
